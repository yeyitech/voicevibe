import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("DashScope") {
                    SecureField("API Key", text: $settingsStore.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Picker("区域", selection: $settingsStore.region) {
                        ForEach(DashScopeRegion.allCases) { region in
                            Text(region.displayName).tag(region)
                        }
                    }

                    TextField("模型", text: $settingsStore.model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("识别参数") {
                    TextField("语言提示（逗号分隔）", text: $settingsStore.languageHintsText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("热词表 ID（可选）", text: $settingsStore.vocabularyID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("说明") {
                    Text("这版仅用于本地技术验证。API Key 会保存在当前设备的 UserDefaults 中，方便调试，但不适合正式上线。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("连接设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}
