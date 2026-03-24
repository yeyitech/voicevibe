import Foundation

actor DashScopeRealtimeASRClient {
    enum ClientEvent: Sendable {
        case taskStarted
        case partialText(String)
        case finalText(String)
        case taskFinished
        case taskFailed(code: String?, message: String)
    }

    enum ClientError: LocalizedError {
        case missingConnection
        case invalidCommand
        case taskStartTimedOut
        case taskFinishTimedOut
        case httpError(statusCode: Int, message: String)
        case serverError(code: String?, message: String)

        var errorDescription: String? {
            switch self {
            case .missingConnection:
                return "WebSocket 连接尚未建立。"
            case .invalidCommand:
                return "无法编码 WebSocket 请求。"
            case .taskStartTimedOut:
                return "等待 task-started 超时。"
            case .taskFinishTimedOut:
                return "等待 task-finished 超时。"
            case .httpError(_, let message):
                return message
            case .serverError(let code, let message):
                if let code {
                    return "阿里云返回错误 \(code): \(message)"
                }
                return "阿里云返回错误: \(message)"
            }
        }
    }

    private struct RunTaskCommand: Encodable {
        struct Header: Encodable {
            let action: String
            let taskID: String
            let streaming: String

            enum CodingKeys: String, CodingKey {
                case action
                case taskID = "task_id"
                case streaming
            }
        }

        struct Payload: Encodable {
            struct Parameters: Encodable {
                let format: String
                let sampleRate: Int
                let vocabularyID: String?
                let languageHints: [String]?

                enum CodingKeys: String, CodingKey {
                    case format
                    case sampleRate = "sample_rate"
                    case vocabularyID = "vocabulary_id"
                    case languageHints = "language_hints"
                }
            }

            struct EmptyInput: Encodable {}

            let taskGroup: String
            let task: String
            let function: String
            let model: String
            let parameters: Parameters
            let input: EmptyInput

            enum CodingKeys: String, CodingKey {
                case taskGroup = "task_group"
                case task
                case function
                case model
                case parameters
                case input
            }
        }

        let header: Header
        let payload: Payload
    }

    private struct FinishTaskCommand: Encodable {
        struct Header: Encodable {
            let action: String
            let taskID: String
            let streaming: String

            enum CodingKeys: String, CodingKey {
                case action
                case taskID = "task_id"
                case streaming
            }
        }

        struct Payload: Encodable {
            struct EmptyInput: Encodable {}

            let input: EmptyInput
        }

        let header: Header
        let payload: Payload
    }

    private struct ServerEnvelope: Decodable {
        struct Header: Decodable {
            let event: String?
            let taskID: String?
            let errorCode: String?
            let errorMessage: String?

            enum CodingKeys: String, CodingKey {
                case event
                case taskID = "task_id"
                case errorCode = "error_code"
                case errorMessage = "error_message"
            }
        }

        struct Payload: Decodable {
            struct Output: Decodable {
                struct Sentence: Decodable {
                    let text: String?
                    let sentenceEnd: Bool?
                    let heartbeat: Bool?

                    enum CodingKeys: String, CodingKey {
                        case text
                        case sentenceEnd = "sentence_end"
                        case heartbeat
                    }
                }

                let sentence: Sentence?
            }

            let output: Output?
        }

        let header: Header
        let payload: Payload?
    }

    private let configuration: DashScopeConfiguration
    private let eventHandler: @Sendable (ClientEvent) -> Void
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private var session: URLSession?
    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveLoopTask: Task<Void, Never>?
    private var currentTaskID: String?

    private var taskStartedContinuation: CheckedContinuation<Void, Error>?
    private var taskFinishedContinuation: CheckedContinuation<Void, Error>?
    private var taskStartTimeoutTask: Task<Void, Never>?
    private var taskFinishTimeoutTask: Task<Void, Never>?
    private var pendingTaskStartResult: Result<Void, Error>?
    private var pendingTaskFinishResult: Result<Void, Error>?
    private var hasReceivedTerminalEvent = false
    private var isDisconnecting = false

    init(
        configuration: DashScopeConfiguration,
        eventHandler: @escaping @Sendable (ClientEvent) -> Void
    ) {
        self.configuration = configuration
        self.eventHandler = eventHandler
    }

    func connectAndStartTask() async throws {
        try await openConnectionIfNeeded()

        let taskID = UUID().uuidString.lowercased()
        currentTaskID = taskID
        hasReceivedTerminalEvent = false
        isDisconnecting = false
        pendingTaskStartResult = nil
        pendingTaskFinishResult = nil

        try await send(command: makeRunTaskCommand(taskID: taskID))
        try await waitForTaskStart()
    }

    func sendAudioChunk(_ audioChunk: Data) async throws {
        guard let webSocketTask else {
            throw ClientError.missingConnection
        }

        try await webSocketTask.send(.data(audioChunk))
    }

    func finishTask() async throws {
        guard let currentTaskID else {
            throw ClientError.missingConnection
        }

        try await send(
            command: FinishTaskCommand(
                header: .init(action: "finish-task", taskID: currentTaskID, streaming: "duplex"),
                payload: .init(input: .init())
            )
        )
        try await waitForTaskFinish()
    }

    func disconnect() {
        isDisconnecting = true
        taskStartTimeoutTask?.cancel()
        taskFinishTimeoutTask?.cancel()
        receiveLoopTask?.cancel()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        session?.invalidateAndCancel()

        taskStartedContinuation = nil
        taskFinishedContinuation = nil
        pendingTaskStartResult = nil
        pendingTaskFinishResult = nil
        receiveLoopTask = nil
        webSocketTask = nil
        session = nil
        currentTaskID = nil
    }

    private func openConnectionIfNeeded() async throws {
        guard webSocketTask == nil else { return }

        var request = URLRequest(url: configuration.websocketURL)
        request.setValue("bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default)
        let webSocketTask = session.webSocketTask(with: request)

        self.session = session
        self.webSocketTask = webSocketTask
        webSocketTask.resume()

        receiveLoopTask = Task { [weak self] in
            await self?.receiveLoop()
        }
    }

    private func send<T: Encodable>(command: T) async throws {
        guard let webSocketTask else {
            throw ClientError.missingConnection
        }

        let data = try encoder.encode(command)
        guard let messageText = String(data: data, encoding: .utf8) else {
            throw ClientError.invalidCommand
        }

        try await webSocketTask.send(.string(messageText))
    }

    private func waitForTaskStart() async throws {
        if let pendingTaskStartResult {
            self.pendingTaskStartResult = nil
            return try pendingTaskStartResult.get()
        }

        try await withCheckedThrowingContinuation { continuation in
            taskStartedContinuation = continuation
            taskStartTimeoutTask?.cancel()
            taskStartTimeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(10))
                await self?.resumeTaskStartContinuationIfNeeded(with: ClientError.taskStartTimedOut)
            }
        }
    }

    private func waitForTaskFinish() async throws {
        if let pendingTaskFinishResult {
            self.pendingTaskFinishResult = nil
            return try pendingTaskFinishResult.get()
        }

        try await withCheckedThrowingContinuation { continuation in
            taskFinishedContinuation = continuation
            taskFinishTimeoutTask?.cancel()
            taskFinishTimeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(10))
                await self?.resumeTaskFinishContinuationIfNeeded(with: ClientError.taskFinishTimedOut)
            }
        }
    }

    private func resumeTaskStartContinuationIfNeeded(with error: Error? = nil) {
        taskStartTimeoutTask?.cancel()
        taskStartTimeoutTask = nil

        guard let taskStartedContinuation else {
            pendingTaskStartResult = error.map { .failure($0) } ?? .success(())
            return
        }
        self.taskStartedContinuation = nil

        if let error {
            taskStartedContinuation.resume(throwing: error)
        } else {
            taskStartedContinuation.resume()
        }
    }

    private func resumeTaskFinishContinuationIfNeeded(with error: Error? = nil) {
        taskFinishTimeoutTask?.cancel()
        taskFinishTimeoutTask = nil

        guard let taskFinishedContinuation else {
            pendingTaskFinishResult = error.map { .failure($0) } ?? .success(())
            return
        }
        self.taskFinishedContinuation = nil

        if let error {
            taskFinishedContinuation.resume(throwing: error)
        } else {
            taskFinishedContinuation.resume()
        }
    }

    private func receiveLoop() async {
        guard let webSocketTask else { return }

        do {
            while !Task.isCancelled {
                let message = try await webSocketTask.receive()
                try await handle(message: message)
            }
        } catch is CancellationError {
        } catch {
            if isDisconnecting || hasReceivedTerminalEvent {
                return
            }
            let clientError = mappedClientError(from: error)
            eventHandler(.taskFailed(code: nil, message: clientError.localizedDescription))
            resumeTaskStartContinuationIfNeeded(with: clientError)
            resumeTaskFinishContinuationIfNeeded(with: clientError)
            disconnect()
        }
    }

    private func handle(message: URLSessionWebSocketTask.Message) async throws {
        switch message {
        case .string(let text):
            try await handle(text: text)
        case .data(let data):
            guard let text = String(data: data, encoding: .utf8) else { return }
            try await handle(text: text)
        @unknown default:
            break
        }
    }

    private func handle(text: String) async throws {
        let data = Data(text.utf8)
        let envelope = try decoder.decode(ServerEnvelope.self, from: data)

        switch envelope.header.event {
        case "task-started":
            resumeTaskStartContinuationIfNeeded()
            eventHandler(.taskStarted)
        case "result-generated":
            guard
                let sentence = envelope.payload?.output?.sentence,
                sentence.heartbeat != true,
                let text = sentence.text,
                !text.isEmpty
            else {
                return
            }

            if sentence.sentenceEnd == true {
                eventHandler(.finalText(text))
            } else {
                eventHandler(.partialText(text))
            }
        case "task-finished":
            hasReceivedTerminalEvent = true
            resumeTaskFinishContinuationIfNeeded()
            eventHandler(.taskFinished)
        case "task-failed":
            hasReceivedTerminalEvent = true
            let error = ClientError.serverError(
                code: envelope.header.errorCode,
                message: envelope.header.errorMessage ?? "Unknown error"
            )
            eventHandler(.taskFailed(code: envelope.header.errorCode, message: error.localizedDescription))
            resumeTaskStartContinuationIfNeeded(with: error)
            resumeTaskFinishContinuationIfNeeded(with: error)
            disconnect()
        default:
            break
        }
    }

    private func makeRunTaskCommand(taskID: String) -> RunTaskCommand {
        let languageHints = configuration.languageHints.isEmpty ? nil : configuration.languageHints
        let vocabularyID = configuration.vocabularyID?.nilIfBlank

        return RunTaskCommand(
            header: .init(action: "run-task", taskID: taskID, streaming: "duplex"),
            payload: .init(
                taskGroup: "audio",
                task: "asr",
                function: "recognition",
                model: configuration.model,
                parameters: .init(
                    format: "pcm",
                    sampleRate: 16_000,
                    vocabularyID: vocabularyID,
                    languageHints: languageHints
                ),
                input: .init()
            )
        )
    }

    private func mappedClientError(from error: Error) -> ClientError {
        if let clientError = error as? ClientError {
            return clientError
        }

        if let response = webSocketTask?.response as? HTTPURLResponse {
            return .httpError(
                statusCode: response.statusCode,
                message: httpErrorMessage(for: response.statusCode)
            )
        }

        return .serverError(code: nil, message: error.localizedDescription)
    }

    private func httpErrorMessage(for statusCode: Int) -> String {
        switch statusCode {
        case 401:
            return "ASR 服务鉴权失败（HTTP 401）。请检查 API Key 是否有效，以及接入区域或连接地址是否匹配。"
        case 403:
            return "ASR 服务拒绝访问（HTTP 403）。请检查账号权限、API Key 和当前接入区域。"
        case 404:
            return "ASR 连接地址不存在（HTTP 404）。请检查当前连接地址是否填写正确。"
        default:
            return "ASR 服务连接失败（HTTP \(statusCode)）。请检查 API Key、接入区域和连接地址。"
        }
    }
}
