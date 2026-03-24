import AppKit
import ApplicationServices
import Combine
import OSLog
import SwiftUI

@MainActor
final class MacAppModel: ObservableObject {
    struct EventLogEntry: Identifiable, Equatable {
        let id = UUID()
        let timestamp: Date
        let message: String

        var displayText: String {
            "\(Self.formatter.string(from: timestamp))  \(message)"
        }

        private static let formatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return formatter
        }()
    }

    @Published private(set) var recordingState: RecordingState = .idle
    @Published private(set) var liveTranscript = ""
    @Published private(set) var committedTranscript = ""
    @Published private(set) var lastInsertedText = ""
    @Published private(set) var lastError: String?
    @Published private(set) var lockedTargetSummary = "未锁定"
    @Published private(set) var lastInjectionStrategyDescription = "暂无"
    @Published private(set) var eventLog: [EventLogEntry] = []
    @Published private(set) var lastRecordingDuration: TimeInterval = 0
    @Published private(set) var lastTranscribedCharacterCount = 0
    @Published private(set) var lastTranscriptPreview = ""
    @Published private(set) var totalTranscriptionCount = 0
    @Published private(set) var totalRecordingDuration: TimeInterval = 0
    @Published private(set) var totalTranscribedCharacterCount = 0
    @Published private(set) var totalAutoInsertCount = 0
    @Published private(set) var totalClipboardFallbackCount = 0

    @Published private(set) var microphonePermission: PermissionState = .undetermined
    @Published private(set) var accessibilityPermission: PermissionState = .undetermined
    @Published private(set) var inputMonitoringPermission: PermissionState = .undetermined
    @Published private(set) var postEventsPermission: PermissionState = .undetermined

    let settingsStore: SettingsStore

    private let audioCaptureService = MacAudioCaptureService()
    private let shortcutMonitor = FnKeyMonitor()
    private let textInjector = FocusedTextInjector()
    private let overlayController = CapsuleOverlayWindowController()
    private let logger = Logger(subsystem: "com.psyhitech.voicevibe.mac", category: "voice")
    private let defaults = UserDefaults.standard

    private var asrClient: DashScopeRealtimeASRClient?
    private var currentConfiguration: DashScopeConfiguration?
    private var currentInputTarget: FocusedInputTarget?
    private var cancellables = Set<AnyCancellable>()
    private var isShortcutCurrentlyHeld = false
    private var isStartingRecording = false
    private var pendingStopAfterStart = false

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore

        shortcutMonitor.onPress = { [weak self] in
            Task { @MainActor [weak self] in
                self?.isShortcutCurrentlyHeld = true
                await self?.startRecordingIfPossible(triggeredByShortcut: true)
            }
        }
        shortcutMonitor.onRelease = { [weak self] in
            Task { @MainActor [weak self] in
                self?.isShortcutCurrentlyHeld = false
                await self?.stopRecordingIfNeeded(triggeredByShortcut: true)
            }
        }

        settingsStore.$triggerMode
            .receive(on: RunLoop.main)
            .sink { [weak self] triggerMode in
                self?.shortcutMonitor.triggerMode = triggerMode
                self?.appendLog("触发键更新为 \(triggerMode.displayName)")
                self?.startShortcutMonitoringIfPossible()
            }
            .store(in: &cancellables)

        loadHistoricalStats()
        refreshPermissions()
        startShortcutMonitoringIfPossible()
    }

    var menuBarSymbolName: String {
        recordingState.menuBarSymbolName
    }

    var microphonePermissionTitle: String {
        microphonePermission.title
    }

    var accessibilityPermissionTitle: String {
        accessibilityPermission.title
    }

    var inputMonitoringPermissionTitle: String {
        inputMonitoringPermission.title
    }

    var postEventsPermissionTitle: String {
        postEventsPermission.title
    }

    var triggerModeTitle: String {
        settingsStore.triggerMode.displayName
    }

    var triggerModeHint: String {
        settingsStore.triggerMode.hint
    }

    var canInsertCommittedTranscriptNow: Bool {
        committedTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var canCopyCommittedTranscript: Bool {
        canInsertCommittedTranscriptNow
    }

    var shortcutStatusSummary: String {
        if shortcutMonitor.isGlobalMonitoringActive {
            return "全局可用"
        }
        if shortcutMonitor.isLocalMonitoringActive {
            return "仅窗口内可用"
        }
        return "未启动"
    }

    var lastRecordingDurationLabel: String {
        guard lastRecordingDuration > 0 else { return "暂无" }
        return String(format: "%.1f 秒", lastRecordingDuration)
    }

    var lastTranscribedCharacterCountLabel: String {
        lastTranscribedCharacterCount > 0 ? "\(lastTranscribedCharacterCount) 字" : "暂无"
    }

    var totalTranscriptionCountLabel: String {
        totalTranscriptionCount > 0 ? "\(totalTranscriptionCount) 次" : "暂无"
    }

    var totalRecordingDurationLabel: String {
        totalRecordingDuration > 0 ? String(format: "%.1f 秒", totalRecordingDuration) : "暂无"
    }

    var totalTranscribedCharacterCountLabel: String {
        totalTranscribedCharacterCount > 0 ? "\(totalTranscribedCharacterCount) 字" : "暂无"
    }

    var totalResultLandingLabel: String {
        let autoText = totalAutoInsertCount > 0 ? "自动插入 \(totalAutoInsertCount)" : nil
        let clipboardText = totalClipboardFallbackCount > 0 ? "剪贴板 \(totalClipboardFallbackCount)" : nil
        return [autoText, clipboardText].compactMap { $0 }.joined(separator: " / ").nilIfBlank ?? "暂无"
    }

    func refreshPermissions() {
        microphonePermission = audioCaptureService.permissionState()
        accessibilityPermission = AXIsProcessTrusted() ? .granted : .denied
        inputMonitoringPermission = CGPreflightListenEventAccess() ? .granted : .undetermined
        postEventsPermission = CGPreflightPostEventAccess() ? .granted : .undetermined

        appendLog(
            "权限刷新: mic=\(microphonePermission.title), ax=\(accessibilityPermission.title), listen=\(inputMonitoringPermission.title), post=\(postEventsPermission.title)"
        )
        startShortcutMonitoringIfPossible()
    }

    func promptForPermissions() async {
        if microphonePermission != .granted {
            let granted = await audioCaptureService.requestPermission()
            microphonePermission = granted ? .granted : .denied
        }

        if accessibilityPermission != .granted {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }

        if !CGPreflightListenEventAccess() {
            _ = CGRequestListenEventAccess()
        }

        if !CGPreflightPostEventAccess() {
            _ = CGRequestPostEventAccess()
        }

        try? await Task.sleep(for: .seconds(1))
        appendLog("已请求系统权限")
        refreshPermissions()
    }

    func startManualRecording() {
        Task {
            await startRecordingIfPossible(triggeredByShortcut: false)
        }
    }

    func stopManualRecording() {
        Task {
            await stopRecordingIfNeeded(triggeredByShortcut: false)
        }
    }

    func copyCommittedTranscript() {
        let finalText = committedTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard finalText.isEmpty == false else { return }

        copyTextToPasteboard(finalText, reason: "手动复制最终文本")
    }

    func insertCommittedTranscriptNow() {
        let finalText = committedTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard finalText.isEmpty == false else { return }

        Task {
            do {
                let target = try textInjector.captureFocusedInputTarget()
                currentInputTarget = target
                lockedTargetSummary = target.summary.nilIfBlank ?? "未知输入目标"
                let strategy = try textInjector.insert(text: finalText, into: target)
                lastInsertedText = finalText
                lastInjectionStrategyDescription = strategy.displayName
                recordingState = .inserted(finalText)
                overlayController.show(.inserted(finalText), hidesAfter: 1.4)
                appendLog("手动插入成功: \(strategy.displayName)")
                currentInputTarget = nil
            } catch {
                presentError(error.localizedDescription)
            }
        }
    }

    func clearResults() {
        liveTranscript = ""
        committedTranscript = ""
        lastInsertedText = ""
        lastError = nil
        lastInjectionStrategyDescription = "暂无"
        lockedTargetSummary = "未锁定"
        lastRecordingDuration = 0
        lastTranscribedCharacterCount = 0
        lastTranscriptPreview = ""
        currentInputTarget = nil
        recordingState = .idle
        appendLog("已清空当前结果")
    }

    func openSystemSettings() {
        openSystemSettingsPane()
    }

    private func startShortcutMonitoringIfPossible() {
        shortcutMonitor.triggerMode = settingsStore.triggerMode
        _ = shortcutMonitor.start(allowGlobalTap: inputMonitoringPermission.isGranted)

        if shortcutMonitor.isGlobalMonitoringActive {
            appendLog("全局触发监听已启动: \(triggerModeTitle)")
        } else if shortcutMonitor.isLocalMonitoringActive {
            appendLog("缺少 Input Monitoring，当前仅支持 VoiceVibe 窗口内快捷键: \(triggerModeTitle)")
        } else {
            appendLog("快捷键监听启动失败")
        }
    }

    private func startRecordingIfPossible(triggeredByShortcut: Bool) async {
        guard recordingState.canStartManually else { return }
        guard !isStartingRecording else { return }

        guard let configuration = settingsStore.activeConfiguration else {
            presentError("请先配置 DashScope API Key。")
            return
        }
        currentConfiguration = configuration

        isStartingRecording = true
        pendingStopAfterStart = false
        defer {
            isStartingRecording = false
        }

        if microphonePermission != .granted {
            let granted = await audioCaptureService.requestPermission()
            microphonePermission = granted ? .granted : .denied
        }
        guard microphonePermission.isGranted else {
            presentError("麦克风权限未授予，无法开始录音。")
            return
        }

        liveTranscript = ""
        committedTranscript = ""
        lastInsertedText = ""
        lastError = nil
        lastInjectionStrategyDescription = "暂无"
        currentInputTarget = nil
        lockedTargetSummary = "未锁定"

        if accessibilityPermission.isGranted {
            do {
                currentInputTarget = try textInjector.captureFocusedInputTarget()
                lockedTargetSummary = currentInputTarget?.summary.nilIfBlank ?? "未知输入目标"
                appendLog("已锁定输入目标: \(lockedTargetSummary)")
            } catch {
                lockedTargetSummary = "未锁定（开始录音时没有有效输入框）"
                appendLog("未锁定输入目标: \(error.localizedDescription)")
            }
        } else {
            lockedTargetSummary = "未锁定（未授予 Accessibility）"
            appendLog("继续录音，但未锁定输入目标: 缺少 Accessibility")
        }

        recordingState = .recording
        overlayController.show(.recording)
        appendLog(triggeredByShortcut ? "通过全局快捷键开始录音" : "通过主窗口按钮开始录音")

        do {
            try audioCaptureService.startCapture()
            appendLog("本地录音已开始")
            if triggeredByShortcut && (!isShortcutCurrentlyHeld || pendingStopAfterStart) {
                appendLog("检测到快捷键已松开，启动完成后立即停止录音")
                pendingStopAfterStart = false
                await stopRecordingIfNeeded(triggeredByShortcut: true)
            }
        } catch {
            audioCaptureService.cancelCapture()
            presentError(error.localizedDescription)
        }
    }

    private func stopRecordingIfNeeded(triggeredByShortcut: Bool) async {
        if triggeredByShortcut && isStartingRecording {
            pendingStopAfterStart = true
            appendLog("收到松键事件，等待录音启动完成后补停")
            return
        }

        guard recordingState == .recording else { return }
        guard let currentConfiguration else {
            presentError("录音会话缺少 ASR 配置。")
            return
        }

        recordingState = .transcribing
        overlayController.show(.transcribing)
        let audioData = audioCaptureService.stopCapture()
        appendLog(triggeredByShortcut ? "通过全局快捷键停止录音" : "通过主窗口按钮停止录音")

        guard audioData.isEmpty == false else {
            presentError("没有录到有效音频。")
            return
        }

        lastRecordingDuration = Double(audioData.count) / 32_000.0
        appendLog("录音已结束，原始 PCM 大小: \(audioData.count) bytes")

        if let wavURL = audioCaptureService.saveAsWAVFile(audioData) {
            appendLog("已保存 WAV: \(wavURL.lastPathComponent)")
        }

        let client = DashScopeRealtimeASRClient(configuration: currentConfiguration) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleASREvent(event)
            }
        }
        asrClient = client

        do {
            try await client.connectAndStartTask()
            appendLog("ASR 连接建立成功，开始发送完整录音")
            try await sendBufferedAudio(audioData, via: client)
            try await client.finishTask()
            await teardownASRSession()
            handleFinalTranscriptReady()
        } catch {
            await teardownASRSession()
            presentError(error.localizedDescription)
        }
    }

    private func handleASREvent(_ event: DashScopeRealtimeASRClient.ClientEvent) {
        switch event {
        case .taskStarted:
            appendLog("服务端返回 task-started")
        case .partialText(let text):
            liveTranscript = text
            appendLog("收到 partial: \(text)")
        case .finalText(let text):
            committedTranscript += text
            liveTranscript = ""
            appendLog("收到 final: \(text)")
        case .taskFinished:
            liveTranscript = ""
            appendLog("服务端返回 task-finished")
        case .taskFailed(_, let message):
            Task {
                await teardownASRSession()
                presentError(message)
            }
        }
    }

    private func sendBufferedAudio(_ audioData: Data, via client: DashScopeRealtimeASRClient) async throws {
        let chunkSize = 16 * 1024
        var offset = 0

        while offset < audioData.count {
            let end = min(offset + chunkSize, audioData.count)
            try await client.sendAudioChunk(audioData.subdata(in: offset..<end))
            offset = end
            try await Task.sleep(for: .milliseconds(50))
        }

        appendLog("完整录音发送完成")
    }

    private func handleFinalTranscriptReady() {
        let finalText = committedTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard finalText.isEmpty == false else {
            presentError("没有拿到可插入的最终文本。")
            return
        }

        lastTranscribedCharacterCount = finalText.count
        lastTranscriptPreview = finalText
        totalTranscriptionCount += 1
        totalRecordingDuration += lastRecordingDuration
        totalTranscribedCharacterCount += finalText.count

        if let currentInputTarget {
            do {
                let strategy = try textInjector.insert(text: finalText, into: currentInputTarget)
                lastInsertedText = finalText
                lastInjectionStrategyDescription = strategy.displayName
                recordingState = .inserted(finalText)
                overlayController.show(.inserted(finalText), hidesAfter: 1.4)
                appendLog("自动插入成功: \(strategy.displayName)")
                totalAutoInsertCount += 1
                persistHistoricalStats()
                self.currentInputTarget = nil
                return
            } catch {
                appendLog("自动插入失败，回退到剪贴板: \(error.localizedDescription)")
            }
        }

        copyTextToPasteboard(finalText, reason: "未找到可插入位置，已自动复制到剪贴板")
        recordingState = .readyToInsert(finalText)
        lastInjectionStrategyDescription = "已复制到剪贴板"
        overlayController.show(.readyToInsert(finalText), hidesAfter: 1.8)
        appendLog("最终文本已保留，同时已复制到剪贴板")
        totalClipboardFallbackCount += 1
        persistHistoricalStats()
        self.currentInputTarget = nil
    }

    private func openSystemSettingsPane() {
        let workspace = NSWorkspace.shared
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_PostEvent"
        ]

        for candidate in candidates {
            if let url = URL(string: candidate), workspace.open(url) {
                appendLog("已尝试打开系统设置")
                return
            }
        }

        workspace.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        appendLog("已打开系统设置")
    }

    private func teardownASRSession() async {
        if let asrClient {
            await asrClient.disconnect()
        }
        self.asrClient = nil
        self.currentConfiguration = nil
    }

    private func appendLog(_ message: String) {
        eventLog.insert(EventLogEntry(timestamp: Date(), message: message), at: 0)
        if eventLog.count > 60 {
            eventLog.removeLast(eventLog.count - 60)
        }
        logger.log("\(message, privacy: .public)")
    }

    private func loadHistoricalStats() {
        totalTranscriptionCount = defaults.integer(forKey: StatsKeys.totalTranscriptionCount)
        totalRecordingDuration = defaults.double(forKey: StatsKeys.totalRecordingDuration)
        totalTranscribedCharacterCount = defaults.integer(forKey: StatsKeys.totalTranscribedCharacterCount)
        totalAutoInsertCount = defaults.integer(forKey: StatsKeys.totalAutoInsertCount)
        totalClipboardFallbackCount = defaults.integer(forKey: StatsKeys.totalClipboardFallbackCount)
    }

    private func persistHistoricalStats() {
        defaults.set(totalTranscriptionCount, forKey: StatsKeys.totalTranscriptionCount)
        defaults.set(totalRecordingDuration, forKey: StatsKeys.totalRecordingDuration)
        defaults.set(totalTranscribedCharacterCount, forKey: StatsKeys.totalTranscribedCharacterCount)
        defaults.set(totalAutoInsertCount, forKey: StatsKeys.totalAutoInsertCount)
        defaults.set(totalClipboardFallbackCount, forKey: StatsKeys.totalClipboardFallbackCount)
    }

    private func copyTextToPasteboard(_ text: String, reason: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        appendLog(reason)
    }

    private func normalizedErrorMessage(_ message: String) -> String {
        switch message {
        case "NO_VALID_AUDIO_ERROR":
            return "没有检测到有效语音。请确认麦克风输入正常，并至少说出半秒以上的内容。"
        default:
            if message.contains("Missing required parameter 'payload'") {
                return "ASR finish-task 请求格式错误。当前构建已修复这个问题，请重新运行最新版本。"
            }
            return message
        }
    }

    private func presentError(_ message: String) {
        let normalizedMessage = normalizedErrorMessage(message)
        lastError = normalizedMessage
        recordingState = .error(normalizedMessage)
        overlayController.show(.error(normalizedMessage), hidesAfter: 2.2)
        appendLog("错误: \(normalizedMessage)")
    }
}

private enum StatsKeys {
    static let totalTranscriptionCount = "stats.totalTranscriptionCount"
    static let totalRecordingDuration = "stats.totalRecordingDuration"
    static let totalTranscribedCharacterCount = "stats.totalTranscribedCharacterCount"
    static let totalAutoInsertCount = "stats.totalAutoInsertCount"
    static let totalClipboardFallbackCount = "stats.totalClipboardFallbackCount"
}
