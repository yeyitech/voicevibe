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

    @Published var websocketURLOverride: String {
        didSet { defaults.set(websocketURLOverride, forKey: Keys.websocketURLOverride) }
    }

    @Published var triggerMode: TriggerMode {
        didSet { defaults.set(triggerMode.rawValue, forKey: Keys.triggerMode) }
    }

    var configurationValidationError: String? {
        if apiKey.nilIfBlank == nil {
            return "请先配置 DashScope API Key。"
        }

        if websocketURLOverride.nilIfBlank != nil, validatedCustomWebSocketURL == nil {
            return "连接地址无效。请粘贴完整的 ws:// 或 wss:// 地址。"
        }

        return nil
    }

    var activeConfiguration: DashScopeConfiguration? {
        guard let apiKey = apiKey.nilIfBlank else { return nil }
        let customWebSocketURLText = websocketURLOverride.nilIfBlank
        let customWebSocketURL = validatedCustomWebSocketURL

        if customWebSocketURLText != nil, customWebSocketURL == nil {
            return nil
        }

        return DashScopeConfiguration(
            apiKey: apiKey,
            region: region,
            model: model.nilIfBlank ?? "fun-asr-realtime",
            vocabularyID: vocabularyID.nilIfBlank,
            languageHints: languageHints,
            customWebSocketURL: customWebSocketURL
        )
    }

    var defaultWebSocketURLString: String {
        region.websocketURL.absoluteString
    }

    var effectiveWebSocketURLString: String {
        validatedCustomWebSocketURL?.absoluteString ?? defaultWebSocketURLString
    }

    var isUsingCustomWebSocketURL: Bool {
        validatedCustomWebSocketURL != nil
    }

    var hasValidCustomWebSocketURL: Bool {
        websocketURLOverride.nilIfBlank == nil || validatedCustomWebSocketURL != nil
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
        let storedAPIKey = defaults.string(forKey: Keys.apiKey)
        let storedRegion = defaults.string(forKey: Keys.region)
        let storedModel = defaults.string(forKey: Keys.model)
        let storedVocabularyID = defaults.string(forKey: Keys.vocabularyID)
        let storedLanguageHints = defaults.string(forKey: Keys.languageHintsText)
        let storedWebSocketURLOverride = defaults.string(forKey: Keys.websocketURLOverride)
        let storedTriggerMode = defaults.string(forKey: Keys.triggerMode)

        // Prefer app-local settings over inherited shell env so terminal launch
        // doesn't silently override what the user configured in the desktop UI.
        self.apiKey = storedAPIKey ?? environment["DASHSCOPE_API_KEY"] ?? ""
        self.region = DashScopeRegion(rawValue: storedRegion ?? environment["DASHSCOPE_REGION"] ?? "") ?? .beijing
        self.model = storedModel ?? environment["DASHSCOPE_MODEL"] ?? "fun-asr-realtime"
        self.vocabularyID = storedVocabularyID ?? environment["DASHSCOPE_VOCABULARY_ID"] ?? ""
        self.languageHintsText = storedLanguageHints ?? environment["DASHSCOPE_LANGUAGE_HINTS"] ?? "zh"
        self.websocketURLOverride = storedWebSocketURLOverride ?? environment["DASHSCOPE_WEBSOCKET_URL"] ?? ""
        self.triggerMode = TriggerMode(rawValue: storedTriggerMode ?? environment["VOICEVIBE_TRIGGER_MODE"] ?? "") ?? .fnHold
    }

    private static func sanitizedAPIKeyInput(_ value: String, fallback: String) -> String {
        let containsMaskGlyph = value.contains("•") || value.contains("⦁")
        if containsMaskGlyph {
            return fallback
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var validatedCustomWebSocketURL: URL? {
        guard let rawValue = websocketURLOverride.nilIfBlank else { return nil }
        guard let url = URL(string: rawValue) else { return nil }
        guard let scheme = url.scheme?.lowercased(), scheme == "ws" || scheme == "wss" else { return nil }
        guard url.host?.isEmpty == false else { return nil }
        return url
    }
}

private enum Keys {
    static let apiKey = "dashscope.apiKey"
    static let region = "dashscope.region"
    static let model = "dashscope.model"
    static let vocabularyID = "dashscope.vocabularyID"
    static let languageHintsText = "dashscope.languageHints"
    static let websocketURLOverride = "dashscope.websocketURLOverride"
    static let triggerMode = "voicevibe.triggerMode"
}
