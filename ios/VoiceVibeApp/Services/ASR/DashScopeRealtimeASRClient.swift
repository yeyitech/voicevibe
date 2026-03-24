import Foundation

@MainActor
final class DashScopeRecordedASRClient {
    enum ClientError: LocalizedError {
        case alreadyTranscribing
        case missingAPIKey
        case invalidURL
        case noTaskID
        case transcriptionFailed(String)

        var errorDescription: String? {
            switch self {
            case .alreadyTranscribing:
                return "上一轮语音识别仍在进行中。"
            case .missingAPIKey:
                return "未配置 DashScope API Key。"
            case .invalidURL:
                return "无效的 DashScope WebSocket 地址。"
            case .noTaskID:
                return "缺少任务 ID。"
            case .transcriptionFailed(let message):
                return "语音识别失败：\(message)"
            }
        }
    }

    var onPartialResult: ((String, Bool) -> Void)?

    private let configuration: DashScopeConfiguration
    private let session: URLSession

    private var webSocketTask: URLSessionWebSocketTask?
    private var taskID: String?
    private var sentenceBuffers: [Int: String] = [:]
    private var transcript = ""
    private var transcriptionContinuation: CheckedContinuation<String, Error>?
    private var receiveTask: Task<Void, Never>?

    init(configuration: DashScopeConfiguration, session: URLSession = URLSession(configuration: .default)) {
        self.configuration = configuration
        self.session = session
    }

    deinit {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        session.invalidateAndCancel()
        receiveTask?.cancel()
    }

    func transcribeRecordedFile(at fileURL: URL) async throws -> String {
        guard transcriptionContinuation == nil else {
            throw ClientError.alreadyTranscribing
        }

        guard !configuration.apiKey.isEmpty else {
            throw ClientError.missingAPIKey
        }

        transcript = ""
        sentenceBuffers.removeAll()

        return try await withCheckedThrowingContinuation { continuation in
            self.transcriptionContinuation = continuation

            Task {
                do {
                    try await self.connectWebSocket()
                    self.startReceivingMessages()
                    try await self.sendRunTask()
                    try await self.sendAudioFile(fileURL)
                    try await self.sendFinishTask()
                } catch {
                    await self.finish(with: .failure(error))
                }
            }
        }
    }

    private func connectWebSocket() async throws {
        var request = URLRequest(url: configuration.websocketURL)
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")

        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
    }

    private func startReceivingMessages() {
        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            guard let self else { return }
            await self.receiveMessages()
        }
    }

    private func sendRunTask() async throws {
        taskID = UUID().uuidString.replacingOccurrences(of: "-", with: "")

        let message: [String: Any] = [
            "header": [
                "action": "run-task",
                "task_id": taskID!,
                "streaming": "duplex"
            ],
            "payload": [
                "task_group": "audio",
                "task": "asr",
                "function": "recognition",
                "model": configuration.model,
                "parameters": [
                    "format": "pcm",
                    "sample_rate": 16000
                ],
                "input": [:]
            ]
        ]

        try await sendJSON(message)
    }

    private func sendAudioFile(_ fileURL: URL) async throws {
        let audioData = try Data(contentsOf: fileURL)
        let chunkSize = 16 * 1024
        var offset = 0

        while offset < audioData.count {
            let end = min(offset + chunkSize, audioData.count)
            let chunk = audioData[offset..<end]
            try await webSocketTask?.send(.data(Data(chunk)))
            offset = end
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    private func sendFinishTask() async throws {
        guard let taskID else {
            throw ClientError.noTaskID
        }

        let message: [String: Any] = [
            "header": [
                "action": "finish-task",
                "task_id": taskID,
                "streaming": "duplex"
            ],
            "payload": [
                "input": [:]
            ]
        ]

        try await sendJSON(message)
    }

    private func receiveMessages() async {
        guard let webSocketTask else { return }

        do {
            while !Task.isCancelled {
                let message = try await webSocketTask.receive()
                switch message {
                case .string(let text):
                    await handleTextMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        await handleTextMessage(text)
                    }
                @unknown default:
                    break
                }
            }
        } catch {
            if shouldIgnoreReceiveError(error) {
                return
            }
            await finish(with: .failure(ClientError.transcriptionFailed(error.localizedDescription)))
        }
    }

    private func handleTextMessage(_ text: String) async {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let header = json["header"] as? [String: Any],
              let event = header["event"] as? String else {
            return
        }

        switch event {
        case "result-generated":
            await handleResultGenerated(json)
        case "task-finished":
            await finish(with: .success(transcript))
        case "task-failed":
            let payload = json["payload"] as? [String: Any]
            let output = payload?["output"] as? [String: Any]
            let message = (payload?["message"] as? String)
                ?? (output?["message"] as? String)
                ?? "转写任务失败"
            await finish(with: .failure(ClientError.transcriptionFailed(message)))
        default:
            break
        }
    }

    private func handleResultGenerated(_ json: [String: Any]) async {
        guard let payload = json["payload"] as? [String: Any],
              let output = payload["output"] as? [String: Any],
              let sentence = output["sentence"] as? [String: Any],
              let sentenceID = sentence["sentence_id"] as? Int else {
            return
        }

        let text = (sentence["text"] as? String) ?? ""
        let sentenceEnd = sentence["sentence_end"] as? Bool ?? false

        if !text.isEmpty {
            sentenceBuffers[sentenceID] = text
            onPartialResult?(text, sentenceEnd)
        }

        if sentenceEnd, let finalText = sentenceBuffers[sentenceID], !finalText.isEmpty {
            transcript += finalText
            sentenceBuffers.removeValue(forKey: sentenceID)
        }
    }

    private func sendJSON(_ message: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: message)
        guard let text = String(data: data, encoding: .utf8) else {
            throw ClientError.transcriptionFailed("无法编码请求")
        }
        try await webSocketTask?.send(.string(text))
    }

    private func finish(with result: Result<String, Error>) async {
        receiveTask?.cancel()
        receiveTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil

        guard let continuation = transcriptionContinuation else { return }
        transcriptionContinuation = nil

        switch result {
        case .success(let transcript):
            continuation.resume(returning: transcript)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    private func shouldIgnoreReceiveError(_ error: Error) -> Bool {
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
