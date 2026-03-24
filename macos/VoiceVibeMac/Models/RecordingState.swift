import Foundation

enum RecordingState: Equatable {
    case idle
    case recording
    case transcribing
    case readyToInsert(String)
    case inserted(String)
    case error(String)

    var title: String {
        switch self {
        case .idle:
            return "待命"
        case .recording:
            return "录音中"
        case .transcribing:
            return "转录中"
        case .readyToInsert:
            return "待处理"
        case .inserted:
            return "已插入"
        case .error:
            return "失败"
        }
    }

    var detail: String {
        switch self {
        case .idle:
            return "按住 Fn 开始录音，松开后自动转写并回填文本。"
        case .recording:
            return "正在采集麦克风音频并实时发送到 DashScope。"
        case .transcribing:
            return "录音已结束，正在等待最终结果并准备回填。"
        case .readyToInsert(let text):
            return text.isEmpty ? "最终文本已生成，等待你复制或手动插入。" : "最终文本已生成：\(text)"
        case .inserted(let text):
            return text.isEmpty ? "最终文本已写入当前输入位置。" : "已写入：\(text)"
        case .error(let message):
            return message
        }
    }

    var canStartManually: Bool {
        switch self {
        case .idle, .readyToInsert, .inserted, .error:
            return true
        case .recording, .transcribing:
            return false
        }
    }

    var canStopManually: Bool {
        self == .recording
    }

    var menuBarSymbolName: String {
        switch self {
        case .idle:
            return "mic"
        case .recording:
            return "waveform.circle.fill"
        case .transcribing:
            return "hourglass"
        case .readyToInsert:
            return "doc.text"
        case .inserted:
            return "text.badge.checkmark"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}
