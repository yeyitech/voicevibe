import SwiftUI

@main
struct VoiceVibeApp: App {
    @StateObject private var settingsStore: SettingsStore
    @StateObject private var viewModel: RecorderViewModel

    init() {
        let settingsStore = SettingsStore()
        _settingsStore = StateObject(wrappedValue: settingsStore)
        _viewModel = StateObject(wrappedValue: RecorderViewModel(settingsStore: settingsStore))
    }

    var body: some Scene {
        WindowGroup {
            HomeView(viewModel: viewModel)
                .environmentObject(settingsStore)
        }
    }
}
