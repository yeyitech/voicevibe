import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: RecorderViewModel
    @EnvironmentObject private var settingsStore: SettingsStore

    @State private var isPresentingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    statusCard
                    transcriptCard
                    controlsCard
                    configurationCard
                }
                .padding(20)
            }
            .navigationTitle("Typeless P0")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingSettings = true
                    } label: {
                        Label("设置", systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $isPresentingSettings) {
                SettingsView(settingsStore: settingsStore)
            }
            .task {
                await viewModel.refreshMicrophonePermission()
            }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("当前状态")
                .font(.headline)

            HStack(spacing: 12) {
                Circle()
                    .fill(viewModel.statusTint)
                    .frame(width: 12, height: 12)

                Text(viewModel.statusTitle)
                    .font(.title3.weight(.semibold))
            }

            Text(viewModel.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("识别结果")
                    .font(.headline)

                Spacer()

                if viewModel.canClearTranscript {
                    Button("清空", role: .destructive) {
                        viewModel.clearTranscript()
                    }
                }
            }

            Text(viewModel.committedTranscript.isEmpty ? "最终文本会显示在这里。" : viewModel.committedTranscript)
                .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemBackground))
                )

            if !viewModel.liveTranscript.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("实时预览")
                        .font(.subheadline.weight(.semibold))
                    Text(viewModel.liveTranscript)
                        .foregroundStyle(.secondary)
                }
            }

            if let lastError = viewModel.lastError {
                Text(lastError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("录音控制")
                .font(.headline)

            Button {
                viewModel.primaryActionTapped()
            } label: {
                HStack {
                    Image(systemName: viewModel.primaryButtonSystemImage)
                    Text(viewModel.primaryButtonTitle)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.primaryButtonTint)
            .disabled(!viewModel.isPrimaryActionEnabled)

            if viewModel.showStopHint {
                Text("录音过程中再次点击即可停止，识别完成后结果会自动保留在上方。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var configurationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("当前配置")
                .font(.headline)

            configurationRow(title: "区域", value: settingsStore.region.displayName)
            configurationRow(title: "模型", value: settingsStore.model)
            configurationRow(title: "语言提示", value: settingsStore.languageHintsSummary)
            configurationRow(title: "热词表", value: settingsStore.vocabularyID.nilIfBlank ?? "未设置")
            configurationRow(title: "API Key", value: settingsStore.apiKeyMasked)
            configurationRow(title: "Key 来源", value: settingsStore.apiKeySourceDescription)

            if settingsStore.shouldShowEnvironmentLaunchHint {
                Text("当前 API Key 来自 Xcode Scheme。只有从 Xcode 点击 Run 启动时才会带上这份环境变量；如果你从手机桌面直接点开 App，会回退到设备本地设置。")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            Text("当前版本为本地 P0 验证，录音结束后会把完整音频送去识别，再将整段文字回填。正式发布前需要把 API Key 迁到后端。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func configurationRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}
