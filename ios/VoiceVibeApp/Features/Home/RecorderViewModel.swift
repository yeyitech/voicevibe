import SwiftUI

@MainActor
final class RecorderViewModel: ObservableObject {
    enum SessionStatus: Equatable {
        case idle
        case connecting
        case recording
        case processing
        case completed
        case error(String)
    }

    enum MicrophonePermissionState {
        case undetermined
        case granted
        case denied
    }

    @Published private(set) var status: SessionStatus = .idle {
        didSet { syncSharedSnapshot() }
    }
    @Published private(set) var liveTranscript = "" {
        didSet { syncSharedSnapshot() }
    }
    @Published private(set) var committedTranscript = "" {
        didSet { syncSharedSnapshot() }
    }
    @Published private(set) var lastError: String? {
        didSet { syncSharedSnapshot() }
    }
    @Published private(set) var microphonePermission: MicrophonePermissionState = .undetermined

    let settingsStore: SettingsStore

    private let audioCaptureService = PCM16MonoAudioCaptureService()
    private let sharedCommandStore = SharedRecorderCommandStore()
    private let sharedRecorderStore = SharedRecorderStore()
    private var currentSessionID: String?
    private var latestResultID: String?
    private var commandPollingTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var lastProcessedCommandID: String?

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        syncSharedSnapshot()
        startCommandPolling()
        startHeartbeat()
    }

    deinit {
        commandPollingTask?.cancel()
        heartbeatTask?.cancel()
    }

    var statusTitle: String {
        switch status {
        case .idle:
            return "待命"
        case .connecting:
            return "连接中"
        case .recording:
            return "录音中"
        case .processing:
            return "识别中"
        case .completed:
            return "已完成"
        case .error:
            return "失败"
        }
    }

    var statusMessage: String {
        switch status {
        case .idle:
            return "配置好 API Key 后即可开始一轮完整的实时语音识别。"
        case .connecting:
            return "正在准备本地录音会话。"
        case .recording:
            return "主 App 正在录音。停止后会把完整录音送去识别，再返回整段文字。"
        case .processing:
            return "录音已结束，正在识别整段语音。"
        case .completed:
            return "这轮识别已经结束，可以继续录下一轮，或切回配置页修改参数。"
        case .error(let message):
            return message
        }
    }

    var statusTint: Color {
        switch status {
        case .idle:
            return .gray
        case .connecting:
            return .orange
        case .recording:
            return .red
        case .processing:
            return .blue
        case .completed:
            return .green
        case .error:
            return .red
        }
    }

    var primaryButtonTitle: String {
        switch status {
        case .recording:
            return "停止录音"
        case .connecting:
            return "连接中..."
        case .processing:
            return "识别中..."
        default:
            return "开始录音"
        }
    }

    var primaryButtonSystemImage: String {
        switch status {
        case .recording:
            return "stop.circle.fill"
        default:
            return "mic.circle.fill"
        }
    }

    var primaryButtonTint: Color {
        switch status {
        case .recording:
            return .red
        default:
            return .accentColor
        }
    }

    var isPrimaryActionEnabled: Bool {
        switch status {
        case .connecting, .processing:
            return false
        default:
            return true
        }
    }

    var showStopHint: Bool {
        status == .recording || status == .completed
    }

    var canClearTranscript: Bool {
        !committedTranscript.isEmpty || !liveTranscript.isEmpty
    }

    func refreshMicrophonePermission() async {
        microphonePermission = audioCaptureService.permissionState()
    }

    func primaryActionTapped() {
        Task {
            if status == .recording {
                await stopRecording()
            } else {
                await startRecording()
            }
        }
    }

    func clearTranscript() {
        committedTranscript = ""
        liveTranscript = ""
        latestResultID = nil
        currentSessionID = nil
        lastError = nil
        if case .completed = status {
            status = .idle
        }
    }

    private func startRecording() async {
        guard settingsStore.activeConfiguration != nil else {
            presentError("请先在设置页填写 DashScope API Key。")
            return
        }

        let isPermissionGranted = await ensureMicrophonePermission()
        guard isPermissionGranted else {
            presentError("麦克风权限被拒绝，无法开始录音。")
            return
        }

        lastError = nil
        latestResultID = nil
        committedTranscript = ""
        liveTranscript = ""
        currentSessionID = UUID().uuidString.lowercased()
        status = .connecting
        print("[Recorder] startRecording requested")

        do {
            try audioCaptureService.startRecording()
            status = .recording
            print("[Recorder] Recording started")
        } catch {
            await teardownSession()
            presentError(error.localizedDescription)
            print("[Recorder] Recording start failed: \(error.localizedDescription)")
        }
    }

    private func stopRecording() async {
        guard status == .recording else { return }

        status = .processing
        print("[Recorder] stopRecording requested")

        do {
            guard let configuration = settingsStore.activeConfiguration else {
                throw PCM16MonoAudioCaptureService.RecordingError.missingRecording
            }

            let recordingURL = try audioCaptureService.stopRecording()
            print("[Recorder] Recording stopped. file=\(recordingURL.lastPathComponent)")
            defer { try? FileManager.default.removeItem(at: recordingURL) }

            let client = DashScopeRecordedASRClient(configuration: configuration)
            client.onPartialResult = { [weak self] text, isFinal in
                guard let self else { return }
                if isFinal {
                    self.committedTranscript += text
                    self.liveTranscript = ""
                } else {
                    self.liveTranscript = text
                }
            }
            let text = try await client.transcribeRecordedFile(at: recordingURL)
            print("[Recorder] Transcription finished. count=\(text.count)")

            committedTranscript = text
            liveTranscript = ""
            latestResultID = currentSessionID
            status = .completed
        } catch {
            await teardownSession()
            presentError(error.localizedDescription)
            print("[Recorder] stop/transcribe failed: \(error.localizedDescription)")
        }
    }

    private func ensureMicrophonePermission() async -> Bool {
        microphonePermission = audioCaptureService.permissionState()
        switch microphonePermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            let granted = await audioCaptureService.requestPermission()
            microphonePermission = granted ? .granted : .denied
            return granted
        }
    }

    private func startCommandPolling() {
        commandPollingTask?.cancel()
        commandPollingTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.processPendingCommand()
                try? await Task.sleep(for: .milliseconds(80))
            }
        }
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await MainActor.run {
                    self.syncSharedSnapshot()
                }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func processPendingCommand() async {
        guard let command = sharedCommandStore.load() else { return }
        guard command.id != lastProcessedCommandID else {
            sharedCommandStore.clear()
            return
        }

        print("[Recorder] Processing command id=\(command.id) action=\(command.action.rawValue)")
        lastProcessedCommandID = command.id
        sharedCommandStore.clear()

        switch command.action {
        case .start:
            guard status != .recording, status != .processing else { return }
            await startRecording()
        case .stop:
            guard status == .recording else { return }
            await stopRecording()
        }
    }

    private func teardownSession() async {
        audioCaptureService.cancelRecording()
    }

    private func presentError(_ message: String) {
        lastError = message
        status = .error(message)
    }

    private func syncSharedSnapshot() {
        sharedRecorderStore.save(
            SharedRecorderSnapshot(
                status: sharedStatus,
                liveTranscript: liveTranscript,
                committedTranscript: committedTranscript,
                latestResultID: latestResultID,
                lastError: lastError,
                updatedAt: Date()
            )
        )
    }

    private var sharedStatus: SharedRecorderStatus {
        switch status {
        case .idle:
            return .idle
        case .connecting:
            return .connecting
        case .recording:
            return .recording
        case .processing:
            return .processing
        case .completed:
            return .completed
        case .error:
            return .error
        }
    }
}
