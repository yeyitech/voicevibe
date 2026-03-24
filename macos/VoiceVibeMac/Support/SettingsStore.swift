import Foundation

enum TriggerMode: String, CaseIterable, Identifiable {
    case fnHold = "fn_hold"
    case rightCommandHold = "right_command_hold"
    case rightOptionHold = "right_option_hold"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fnHold:
            return "Fn"
        case .rightCommandHold:
            return "右 Command"
        case .rightOptionHold:
            return "右 Option"
        }
    }

    var hint: String {
        switch self {
        case .fnHold:
            return "最贴近你设想的交互，但要避免和系统 Globe/Fn 功能冲突。"
        case .rightCommandHold:
            return "适合外接键盘，冲突通常比 Fn 少。"
        case .rightOptionHold:
            return "也适合作为备用长按键，但和部分快捷键组合可能冲突。"
        }
    }
}

final class SettingsStore: ObservableObject {
    @Published var apiKey: String {
        didSet {
            let sanitized = Self.sanitizedAPIKeyInput(apiKey, fallback: oldValue)
            if sanitized != apiKey {
                apiKey = sanitized
                return
            }
            defaults.set(apiKey, forKey: Keys.apiKey)
        }
    }

    @Published var region: DashScopeRegion {
        didSet { defaults.set(region.rawValue, forKey: Keys.region) }
    }

    @Published var model: String {
        didSet { defaults.set(model, forKey: Keys.model) }
    }

    @Published var vocabularyID: String {
        didSet { defaults.set(vocabularyID, forKey: Keys.vocabularyID) }
    }

    @Published var languageHintsText: String {
        didSet { defaults.set(languageHintsText, forKey: Keys.languageHintsText) }
    }

    @Published var triggerMode: TriggerMode {
        didSet { defaults.set(triggerMode.rawValue, forKey: Keys.triggerMode) }
    }

    var activeConfiguration: DashScopeConfiguration? {
        guard let apiKey = apiKey.nilIfBlank else { return nil }

        return DashScopeConfiguration(
            apiKey: apiKey,
            region: region,
            model: model.nilIfBlank ?? "fun-asr-realtime",
            vocabularyID: vocabularyID.nilIfBlank,
            languageHints: languageHints
        )
    }

    var languageHints: [String] {
        languageHintsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var languageHintsSummary: String {
        languageHints.isEmpty ? "未设置" : languageHints.joined(separator: ", ")
    }

    var apiKeyMasked: String {
        guard let apiKey = apiKey.nilIfBlank else { return "未设置" }
        guard apiKey.count > 8 else { return String(repeating: "•", count: apiKey.count) }

        return "••••••\(apiKey.suffix(4))"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let environment = ProcessInfo.processInfo.environment

        self.apiKey = environment["DASHSCOPE_API_KEY"] ?? defaults.string(forKey: Keys.apiKey) ?? ""
        self.region = DashScopeRegion(rawValue: environment["DASHSCOPE_REGION"] ?? defaults.string(forKey: Keys.region) ?? "") ?? .beijing
        self.model = environment["DASHSCOPE_MODEL"] ?? defaults.string(forKey: Keys.model) ?? "fun-asr-realtime"
        self.vocabularyID = environment["DASHSCOPE_VOCABULARY_ID"] ?? defaults.string(forKey: Keys.vocabularyID) ?? ""
        self.languageHintsText = environment["DASHSCOPE_LANGUAGE_HINTS"] ?? defaults.string(forKey: Keys.languageHintsText) ?? "zh"
        self.triggerMode = TriggerMode(rawValue: environment["VOICEVIBE_TRIGGER_MODE"] ?? defaults.string(forKey: Keys.triggerMode) ?? "") ?? .fnHold
    }

    private static func sanitizedAPIKeyInput(_ value: String, fallback: String) -> String {
        let containsMaskGlyph = value.contains("•") || value.contains("⦁")
        if containsMaskGlyph {
            return fallback
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private enum Keys {
    static let apiKey = "dashscope.apiKey"
    static let region = "dashscope.region"
    static let model = "dashscope.model"
    static let vocabularyID = "dashscope.vocabularyID"
    static let languageHintsText = "dashscope.languageHints"
    static let triggerMode = "voicevibe.triggerMode"
}
