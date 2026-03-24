import SwiftUI

enum OverlayState: Equatable {
    case recording
    case transcribing
    case readyToInsert(String)
    case inserted(String)
    case error(String)

    var title: String {
        switch self {
        case .recording:
            return "正在录音"
        case .transcribing:
            return "正在转录"
        case .readyToInsert:
            return "已生成文本"
        case .inserted:
            return "文字已输入"
        case .error:
            return "处理失败"
        }
    }

    var subtitle: String {
        switch self {
        case .recording:
            return "松开 Fn 后结束本轮录音"
        case .transcribing:
            return "等待最终结果并回填到锁定的输入位置"
        case .readyToInsert(let text):
            let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized.isEmpty ? "转写已结束，等待复制或手动插入" : normalized
        case .inserted(let text):
            let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized.isEmpty ? "没有可插入的文本" : normalized
        case .error(let message):
            return message
        }
    }

    var systemImageName: String {
        switch self {
        case .recording:
            return "mic.fill"
        case .transcribing:
            return "waveform.and.magnifyingglass"
        case .readyToInsert:
            return "doc.text.fill"
        case .inserted:
            return "text.badge.checkmark"
        case .error:
            return "exclamationmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .recording:
            return Color(red: 0.88, green: 0.22, blue: 0.17)
        case .transcribing:
            return Color(red: 0.12, green: 0.44, blue: 0.86)
        case .readyToInsert:
            return Color(red: 0.78, green: 0.54, blue: 0.11)
        case .inserted:
            return Color(red: 0.15, green: 0.62, blue: 0.30)
        case .error:
            return Color(red: 0.80, green: 0.20, blue: 0.22)
        }
    }
}
