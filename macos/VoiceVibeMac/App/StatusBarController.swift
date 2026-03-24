import AppKit
import Combine
import SwiftUI

@MainActor
final class WindowRouter: ObservableObject {
    var openMainWindow: (() -> Void)?
}

@MainActor
final class StatusBarController: NSObject, ObservableObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var cancellables = Set<AnyCancellable>()

    private weak var appModel: MacAppModel?
    private weak var windowRouter: WindowRouter?
    private var isConfigured = false

    func configure(appModel: MacAppModel, windowRouter: WindowRouter) {
        self.appModel = appModel
        self.windowRouter = windowRouter

        guard !isConfigured else {
            updateStatusIcon(using: appModel.menuBarSymbolName)
            return
        }

        isConfigured = true
        menu.delegate = self
        statusItem.menu = menu

        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.toolTip = "VoiceVibe"
        }

        updateStatusIcon(using: appModel.menuBarSymbolName)

        appModel.$recordingState
            .receive(on: RunLoop.main)
            .sink { [weak self] recordingState in
                self?.updateStatusIcon(using: recordingState.menuBarSymbolName)
            }
            .store(in: &cancellables)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let appModel else { return }

        menu.removeAllItems()

        let titleItem = NSMenuItem(title: "VoiceVibe", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        let stateItem = NSMenuItem(title: appModel.recordingState.title, action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)

        let triggerItem = NSMenuItem(title: "触发键：\(appModel.triggerModeTitle)", action: nil, keyEquivalent: "")
        triggerItem.isEnabled = false
        menu.addItem(triggerItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "打开主窗口", action: #selector(openMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "刷新权限状态", action: #selector(refreshPermissions), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(terminateApp), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        windowRouter?.openMainWindow?()
    }

    @objc private func refreshPermissions() {
        appModel?.refreshPermissions()
    }

    @objc private func terminateApp() {
        NSApp.terminate(nil)
    }

    private func updateStatusIcon(using symbolName: String) {
        guard let button = statusItem.button else { return }

        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "VoiceVibe"
        ) ?? NSImage(systemSymbolName: "mic", accessibilityDescription: "VoiceVibe")
        image?.isTemplate = true
        button.image = image
    }
}
