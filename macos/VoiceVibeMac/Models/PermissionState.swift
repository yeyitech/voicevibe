import Foundation

enum PermissionState: Equatable {
    case granted
    case denied
    case undetermined

    var title: String {
        switch self {
        case .granted:
            return "已授权"
        case .denied:
            return "未授权"
        case .undetermined:
            return "待确认"
        }
    }

    var isGranted: Bool {
        self == .granted
    }

    var systemImageName: String {
        switch self {
        case .granted:
            return "checkmark.seal.fill"
        case .denied:
            return "xmark.seal.fill"
        case .undetermined:
            return "questionmark.diamond.fill"
        }
    }
}
