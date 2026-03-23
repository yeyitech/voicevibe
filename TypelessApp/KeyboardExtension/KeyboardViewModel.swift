import SwiftUI

@MainActor
final class KeyboardViewModel: ObservableObject {
    enum VisualState {
        case unavailable
        case idle
        case recording
        case processing
        case completed
        case error
    }

    @Published private(set) var snapshot = SharedRecorderSnapshot.empty
    @Published private(set) var lastInsertedResultID: String?
    @Published private(set) var lastInsertedText = ""

    private let sharedRecorderStore = SharedRecorderStore()
    private var refreshTimer: Timer?
    private var keyboardPresentedAt = Date()

    init() {
        refresh()
        startRefreshing()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    var visualState: VisualState {
        if !isHostReachable {
            return .unavailable
        }

        switch snapshot.status {
        case .connecting, .recording:
            return .recording
        case .processing:
            return .processing
        case .completed where shouldShowFreshResult:
            return .completed
        case .error:
            return .error
        default:
            return .idle
        }
    }

    var isHostReachable: Bool {
        Date().timeIntervalSince(snapshot.updatedAt) < 1.2
    }

    private var shouldShowFreshResult: Bool {
        guard !insertableText.isEmpty else { return false }
        guard snapshot.updatedAt >= keyboardPresentedAt else { return false }
        guard let latestResultID = snapshot.latestResultID else { return false }
        return latestResultID != lastInsertedResultID
    }

    var statusTitle: String {
        switch snapshot.status {
        case .idle:
            return "待命"
        case .connecting:
            return "连接中"
        case .recording:
            return "录音中"
        case .processing:
            return "识别中"
        case .completed:
            return "可插入"
        case .error:
            return "失败"
        }
    }

    var statusMessage: String {
        switch snapshot.status {
        case .idle:
            return isHostReachable ? "点按开始录音，完成后会把整段文字回填。" : "主 App 当前不在线，先打开主 App。"
        case .connecting:
            return "主 App 正在准备录音会话。"
        case .recording:
            return "主 App 正在录音。"
        case .processing:
            return "主 App 已停止录音，正在识别整段语音。"
        case .completed:
            return "最近一轮最终文本已经可插入到当前输入框。"
        case .error:
            return snapshot.lastError ?? "主 App 处理本轮语音时失败。"
        }
    }

    var previewText: String {
        if !isHostReachable {
            return "主 App 没有在后台提供语音服务。先打开主 App，再回到需要输入的地方。"
        }
        if !snapshot.liveTranscript.isEmpty {
            return snapshot.liveTranscript
        }
        if !snapshot.committedTranscript.isEmpty {
            return snapshot.committedTranscript
        }
        return "这里会显示主 App 同步过来的实时转写和最近一次最终结果。"
    }

    var primaryActionTitle: String {
        if !isHostReachable {
            return "打开主 App"
        }
        if canInsertCommittedTranscript {
            return hasNewResultAvailable ? "插入最近结果" : "再次插入"
        }
        return "等待最终结果"
    }

    var canInsertCommittedTranscript: Bool {
        shouldShowFreshResult
    }

    var canUndoLastInsert: Bool {
        !lastInsertedText.isEmpty
    }

    var hasNewResultAvailable: Bool {
        shouldShowFreshResult
    }

    var insertableText: String {
        snapshot.committedTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var statusColor: Color {
        switch snapshot.status {
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

    var primaryPrompt: String {
        switch visualState {
        case .unavailable:
            return "先打开 App"
        case .idle:
            return "点击说话"
        case .recording:
            return "再次点击以完成"
        case .processing:
            return "Thinking"
        case .completed:
            return "点击插入结果"
        case .error:
            return "录音失败"
        }
    }

    var primaryButtonSystemImage: String {
        switch visualState {
        case .unavailable:
            return "app.badge"
        case .idle:
            return "mic.fill"
        case .completed:
            return "arrow.up.doc.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .recording:
            return "waveform"
        case .processing:
            return "ellipsis"
        }
    }

    var detailText: String? {
        switch visualState {
        case .completed:
            return insertableText.isEmpty ? nil : insertableText
        case .unavailable:
            return "主 App 离线时，键盘不会假装进入录音态。"
        case .error:
            return snapshot.lastError
        default:
            return nil
        }
    }

    var shouldShowHeader: Bool {
        switch visualState {
        case .unavailable, .idle, .completed, .error:
            return true
        case .recording, .processing:
            return false
        }
    }

    var shouldShowTopActions: Bool {
        shouldShowHeader
    }

    var shouldShowSecondaryAction: Bool {
        shouldShowHeader
    }

    var canPerformPrimaryAction: Bool {
        switch visualState {
        case .idle, .recording, .error:
            return true
        case .processing, .unavailable:
            return false
        case .completed:
            return !insertableText.isEmpty
        }
    }

    func refresh() {
        snapshot = sharedRecorderStore.load()
    }

    func markInsertedCurrentResult() {
        lastInsertedResultID = snapshot.latestResultID
        lastInsertedText = insertableText
    }

    func clearInsertedResult() {
        lastInsertedResultID = nil
        lastInsertedText = ""
    }

    func handleKeyboardPresented() {
        keyboardPresentedAt = Date()
        objectWillChange.send()
    }

    private func startRefreshing() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }
}
