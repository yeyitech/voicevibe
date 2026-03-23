import SwiftUI

struct MainView: View {
    @ObservedObject var appModel: MacAppModel
    @ObservedObject var settingsStore: SettingsStore

    private let ink = Color(red: 0.16, green: 0.13, blue: 0.11)
    private let mutedInk = Color(red: 0.40, green: 0.34, blue: 0.29)
    private let quietInk = Color(red: 0.55, green: 0.48, blue: 0.42)
    private let canvasTop = Color(red: 0.91, green: 0.88, blue: 0.82)
    private let canvasBottom = Color(red: 0.84, green: 0.81, blue: 0.75)
    private let panel = Color(red: 0.97, green: 0.95, blue: 0.91)
    private let panelSoft = Color(red: 0.93, green: 0.90, blue: 0.84)
    private let accent = Color(red: 0.44, green: 0.21, blue: 0.11)
    private let accentSoft = Color(red: 0.90, green: 0.78, blue: 0.63)
    private let border = Color(red: 0.82, green: 0.73, blue: 0.60)

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                heroCard
                permissionCard
                statsCard
                resultCard
                connectionCard
            }
            .frame(maxWidth: 920)
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
        .background(backgroundView.ignoresSafeArea())
    }

    private var backgroundView: some View {
        ZStack {
            LinearGradient(
                colors: [canvasTop, canvasBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [accentSoft.opacity(0.55), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Typeless Mac")
                .font(.system(size: 36, weight: .bold, design: .serif))
                .foregroundStyle(ink)

            Text("主页面只保留三类信息：权限是否齐全、最近一次录音转写表现、以及最近结果落到哪里。连接参数仍然可改，但不再让界面看起来像调试控制台。")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .center, spacing: 12) {
                Label(appModel.recordingState.title, systemImage: appModel.menuBarSymbolName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(accentSoft, in: Capsule())

                Text(appModel.recordingState.detail)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(mutedInk)
            }
        }
        .cardStyle()
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading(
                eyebrow: "Permissions",
                title: "权限状态",
                detail: "输入监控决定能不能在别的 App 里唤起；辅助功能决定能不能直接插入到当前输入框。"
            )

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    permissionTile(title: "麦克风", state: appModel.microphonePermission)
                    permissionTile(title: "辅助功能", state: appModel.accessibilityPermission)
                    permissionTile(title: "输入监控", state: appModel.inputMonitoringPermission)
                    permissionTile(title: "Post Events", state: appModel.postEventsPermission)
                }

                VStack(spacing: 10) {
                    permissionTile(title: "麦克风", state: appModel.microphonePermission)
                    permissionTile(title: "辅助功能", state: appModel.accessibilityPermission)
                    permissionTile(title: "输入监控", state: appModel.inputMonitoringPermission)
                    permissionTile(title: "Post Events", state: appModel.postEventsPermission)
                }
            }

            HStack(spacing: 12) {
                Button("请求权限") {
                    Task {
                        await appModel.promptForPermissions()
                    }
                }
                .buttonStyle(PrimarySurfaceButtonStyle())

                Button("打开系统设置") {
                    appModel.openSystemSettings()
                }
                .buttonStyle(SecondarySurfaceButtonStyle())

                Button("刷新状态") {
                    appModel.refreshPermissions()
                }
                .buttonStyle(SecondarySurfaceButtonStyle())
            }
        }
        .cardStyle()
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading(
                eyebrow: "History",
                title: "累计统计",
                detail: "这里显示的是历史累计结果，不是最近一次会话的瞬时数据。"
            )

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    statTile(title: "累计转写次数", value: appModel.totalTranscriptionCountLabel)
                    statTile(title: "累计录音时长", value: appModel.totalRecordingDurationLabel)
                    statTile(title: "累计转写字数", value: appModel.totalTranscribedCharacterCountLabel)
                    statTile(title: "累计结果落点", value: appModel.totalResultLandingLabel)
                }

                VStack(spacing: 10) {
                    statTile(title: "累计转写次数", value: appModel.totalTranscriptionCountLabel)
                    statTile(title: "累计录音时长", value: appModel.totalRecordingDurationLabel)
                    statTile(title: "累计转写字数", value: appModel.totalTranscribedCharacterCountLabel)
                    statTile(title: "累计结果落点", value: appModel.totalResultLandingLabel)
                }
            }
        }
        .cardStyle()
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading(
                eyebrow: "Result",
                title: "最近结果",
                detail: "当前没有可插入位置时会自动回退到剪贴板；如果你需要，也可以在这里重新手动插入。"
            )

            Text(appModel.lastTranscriptPreview.isEmpty ? "最近一次完整转写会显示在这里。" : appModel.lastTranscriptPreview)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
                .padding(16)
                .background(panelSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            HStack(spacing: 12) {
                Button("复制结果") {
                    appModel.copyCommittedTranscript()
                }
                .buttonStyle(SecondarySurfaceButtonStyle())
                .disabled(!appModel.canCopyCommittedTranscript)

                Button("插入到当前焦点") {
                    appModel.insertCommittedTranscriptNow()
                }
                .buttonStyle(PrimarySurfaceButtonStyle())
                .disabled(!appModel.canInsertCommittedTranscriptNow)
            }
        }
        .cardStyle()
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading(
                eyebrow: "Connection",
                title: "连接配置",
                detail: "API Key 仍然可配置，现在只是默认已有一份配置。"
            )

            SecureField("API Key", text: $settingsStore.apiKey)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(border, lineWidth: 1)
                        )
                )

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("区域")
                segmentedControl(
                    options: DashScopeRegion.allCases,
                    selection: $settingsStore.region,
                    label: { $0.displayName }
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("触发键")
                segmentedControl(
                    options: TriggerMode.allCases,
                    selection: $settingsStore.triggerMode,
                    label: { $0.displayName }
                )
            }

            Text("当前 API Key：\(settingsStore.apiKeyMasked)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(mutedInk)
        }
        .cardStyle()
    }

    private func sectionHeading(eyebrow: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(quietInk)
                .tracking(1.2)

            Text(title)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(ink)

            Text(detail)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(mutedInk)
    }

    private func permissionTile(title: String, state: PermissionState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(mutedInk)

            Label(state.title, systemImage: state.systemImageName)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(panelSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func statTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(mutedInk)

            Text(value)
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .padding(16)
        .background(panelSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func segmentedControl<Option: Identifiable & Hashable>(
        options: [Option],
        selection: Binding<Option>,
        label: @escaping (Option) -> String
    ) -> some View {
        HStack(spacing: 8) {
            ForEach(options) { option in
                Button {
                    selection.wrappedValue = option
                } label: {
                    Text(label(option))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(selection.wrappedValue == option ? ink : mutedInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selection.wrappedValue == option ? accentSoft : panelSoft)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(selection.wrappedValue == option ? accent : border, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct PrimarySurfaceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(red: 0.16, green: 0.13, blue: 0.11))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(configuration.isPressed ? Color(red: 0.83, green: 0.67, blue: 0.48) : Color(red: 0.90, green: 0.78, blue: 0.63))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color(red: 0.44, green: 0.21, blue: 0.11), lineWidth: 1)
                    )
            )
    }
}

private struct SecondarySurfaceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(red: 0.16, green: 0.13, blue: 0.11))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(configuration.isPressed ? Color(red: 0.89, green: 0.85, blue: 0.77) : Color(red: 0.93, green: 0.90, blue: 0.84))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color(red: 0.82, green: 0.73, blue: 0.60), lineWidth: 1)
                    )
            )
    }
}

private extension View {
    func cardStyle() -> some View {
        padding(22)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color(red: 0.97, green: 0.95, blue: 0.91))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(Color(red: 0.82, green: 0.73, blue: 0.60), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 14, y: 8)
            )
    }
}
