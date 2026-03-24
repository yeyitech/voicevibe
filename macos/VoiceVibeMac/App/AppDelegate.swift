import AppKit
import OSLog
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let defaultWindowSize = NSSize(width: 960, height: 780)
    private let minimumWindowSize = NSSize(width: 760, height: 720)

    private let settingsStore = SettingsStore()
    private lazy var appModel = MacAppModel(settingsStore: settingsStore)
    private let windowRouter = WindowRouter()
    private let statusBarController = StatusBarController()
    private let logger = Logger(subsystem: "com.psyhitech.voicevibe.mac", category: "app")

    private var mainWindow: NSWindow?
    private var mainWindowController: NSWindowController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        configureMainMenuIfNeeded()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildMainWindowIfNeeded()
        windowRouter.openMainWindow = { [weak self] in
            self?.showMainWindow()
        }
        statusBarController.configure(appModel: appModel, windowRouter: windowRouter)
        showMainWindow()

        DispatchQueue.main.async { [weak self] in
            self?.showMainWindow()
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        false
    }

    func application(_ application: NSApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        false
    }

    func application(_ application: NSApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    private func buildMainWindowIfNeeded() {
        guard mainWindow == nil else { return }

        let contentView = MainView(appModel: appModel, settingsStore: settingsStore)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: defaultWindowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "VoiceVibe"
        window.minSize = minimumWindowSize
        window.collectionBehavior = [.moveToActiveSpace]
        window.center()
        window.contentViewController = hostingController
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.level = .normal
        window.tabbingMode = .disallowed
        window.setContentSize(defaultWindowSize)
        window.setFrame(centeredFrame(for: defaultWindowSize), display: false)

        let controller = NSWindowController(window: window)
        controller.shouldCascadeWindows = false

        mainWindowController = controller
        mainWindow = window
        logger.notice("Main window created: \(window.frame.debugDescription, privacy: .public)")
    }

    private func showMainWindow() {
        buildMainWindowIfNeeded()
        guard let mainWindow else { return }

        NSApp.setActivationPolicy(.regular)
        NSApp.unhide(nil)
        mainWindow.collectionBehavior = mainWindow.collectionBehavior.union([.moveToActiveSpace])
        mainWindow.level = .normal

        if mainWindow.isMiniaturized {
            mainWindow.deminiaturize(nil)
        }

        if mainWindow.frame.width < defaultWindowSize.width - 40 {
            mainWindow.setContentSize(defaultWindowSize)
        }

        let frame = centeredFrame(for: mainWindow.frame.size)
        mainWindow.setFrame(frame, display: false)

        NSApp.activate(ignoringOtherApps: true)
        mainWindow.setIsVisible(true)
        mainWindowController?.showWindow(nil)
        mainWindow.center()
        mainWindow.orderFrontRegardless()
        mainWindow.makeKeyAndOrderFront(nil)
        mainWindow.makeMain()

        logger.notice(
            "Show main window visible=\(mainWindow.isVisible, privacy: .public) mini=\(mainWindow.isMiniaturized, privacy: .public) frame=\(mainWindow.frame.debugDescription, privacy: .public)"
        )

        DispatchQueue.main.async { [weak self] in
            guard let self, let mainWindow = self.mainWindow else { return }
            if mainWindow.isMiniaturized {
                mainWindow.deminiaturize(nil)
            }
            mainWindow.orderFrontRegardless()
            mainWindow.makeKeyAndOrderFront(nil)
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender === mainWindow else { return true }

        sender.orderOut(nil)
        return false
    }

    private func centeredFrame(for size: NSSize) -> NSRect {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return NSRect(origin: .zero, size: size)
        }

        let visibleFrame = screen.visibleFrame
        let origin = NSPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2
        )
        return NSRect(origin: origin, size: size)
    }

    private func configureMainMenuIfNeeded() {
        guard NSApp.mainMenu == nil else { return }

        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "打开 VoiceVibe",
            action: #selector(openMainWindowFromMenu),
            keyEquivalent: "0"
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "退出 VoiceVibe",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "窗口")
        windowMenu.addItem(
            withTitle: "打开主窗口",
            action: #selector(openMainWindowFromMenu),
            keyEquivalent: "1"
        )
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }

    @objc private func openMainWindowFromMenu() {
        showMainWindow()
    }
}
