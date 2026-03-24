import SwiftUI

@main
struct VoiceVibeMacApp: App {
    @StateObject private var settingsStore: SettingsStore
    @StateObject private var appModel: MacAppModel

    init() {
        let settingsStore = SettingsStore()
        _settingsStore = StateObject(wrappedValue: settingsStore)
        _appModel = StateObject(wrappedValue: MacAppModel(settingsStore: settingsStore))
    }

    var body: some Scene {
        WindowGroup("VoiceVibe", id: "main") {
            MainView(appModel: appModel, settingsStore: settingsStore)
                .frame(minWidth: 560, minHeight: 720)
        }

        MenuBarExtra("VoiceVibe", systemImage: appModel.menuBarSymbolName) {
            MenuBarView(appModel: appModel)
        }
        .menuBarExtraStyle(.window)
    }
}
