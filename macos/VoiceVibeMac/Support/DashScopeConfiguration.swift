import Foundation

enum DashScopeRegion: String, CaseIterable, Identifiable {
    case beijing
    case singapore

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beijing:
            return "Beijing"
        case .singapore:
            return "Singapore"
        }
    }

    var websocketURL: URL {
        switch self {
        case .beijing:
            return URL(string: "wss://dashscope.aliyuncs.com/api-ws/v1/inference")!
        case .singapore:
            return URL(string: "wss://dashscope-intl.aliyuncs.com/api-ws/v1/inference")!
        }
    }
}

struct DashScopeConfiguration {
    let apiKey: String
    let region: DashScopeRegion
    let model: String
    let vocabularyID: String?
    let languageHints: [String]

    var websocketURL: URL {
        region.websocketURL
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
