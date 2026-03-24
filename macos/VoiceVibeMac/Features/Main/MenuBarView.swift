import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appModel: MacAppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: appModel.menuBarSymbolName)
                    .font(.system(size: 18, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("VoiceVibe")
                        .font(.system(size: 14, weight: .semibold))
                    Text(appModel.recordingState.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Text(appModel.recordingState.detail)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("触发键：\(appModel.triggerModeTitle)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Text("锁定目标：\(appModel.lockedTargetSummary)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Button("打开主窗口") {
                openWindow(id: "main")
            }

            Button("刷新权限状态") {
                appModel.refreshPermissions()
            }

            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}
