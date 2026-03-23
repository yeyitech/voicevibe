import Foundation

final class SettingsStore: ObservableObject {
    enum ValueSource {
        case environment
        case bundledDefault
        case local
        case unset
    }

    @Published var apiKey: String {
        didSet {
            defaults.set(apiKey, forKey: Keys.apiKey)
            if !isUsingEnvironmentAPIKey {
                apiKeySource = apiKey.nilIfBlank == nil ? .unset : .local
            }
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

    @Published private(set) var apiKeySource: ValueSource

    var activeConfiguration: DashScopeConfiguration? {
        guard let apiKey = apiKey.nilIfBlank else { return nil }

        return DashScopeConfiguration(
            apiKey: apiKey,
            region: region,
            model: Self.normalizedModelName(model.nilIfBlank),
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

        let suffix = apiKey.suffix(4)
        return "••••••\(suffix)"
    }

    var apiKeySourceDescription: String {
        switch apiKeySource {
        case .environment:
            return "Xcode Scheme 环境变量"
        case .bundledDefault:
            return "应用内默认值"
        case .local:
            return "设备本地设置"
        case .unset:
            return "未设置"
        }
    }

    var shouldShowEnvironmentLaunchHint: Bool {
        apiKeySource == .environment
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let environment = ProcessInfo.processInfo.environment
        let environmentAPIKey = environment["DASHSCOPE_API_KEY"]?.nilIfBlank
        let storedAPIKey = defaults.string(forKey: Keys.apiKey)?.nilIfBlank
        let bundledDefaultAPIKey = Defaults.defaultAPIKey.nilIfBlank

        self.apiKey = environmentAPIKey ?? storedAPIKey ?? bundledDefaultAPIKey ?? ""
        self.apiKeySource = {
            if environmentAPIKey != nil { return .environment }
            if storedAPIKey != nil { return .local }
            if bundledDefaultAPIKey != nil { return .bundledDefault }
            return .unset
        }()
        self.region = DashScopeRegion(rawValue: environment["DASHSCOPE_REGION"] ?? defaults.string(forKey: Keys.region) ?? "") ?? .beijing
        self.model = Self.normalizedModelName(environment["DASHSCOPE_MODEL"] ?? defaults.string(forKey: Keys.model))
        self.vocabularyID = environment["DASHSCOPE_VOCABULARY_ID"] ?? defaults.string(forKey: Keys.vocabularyID) ?? ""
        self.languageHintsText = environment["DASHSCOPE_LANGUAGE_HINTS"] ?? defaults.string(forKey: Keys.languageHintsText) ?? "zh"
    }

    private var isUsingEnvironmentAPIKey: Bool {
        ProcessInfo.processInfo.environment["DASHSCOPE_API_KEY"]?.nilIfBlank != nil
    }

    private static func normalizedModelName(_ rawValue: String?) -> String {
        switch rawValue?.nilIfBlank {
        case nil:
            return "fun-asr-realtime"
        case let value?:
            return value
        }
    }
}

private enum Keys {
    static let apiKey = "dashscope.apiKey"
    static let region = "dashscope.region"
    static let model = "dashscope.model"
    static let vocabularyID = "dashscope.vocabularyID"
    static let languageHintsText = "dashscope.languageHints"
}

private enum Defaults {
    static let defaultAPIKey = "sk-481cfc0c14b44bdea612bea3a3b8f0e6"
}
