import AppKit
import SwiftUI

@MainActor
final class CapsuleOverlayWindowController {
    private let panel: NSPanel
    private let hostingController: NSHostingController<CapsuleOverlayView>
    private var hideWorkItem: DispatchWorkItem?

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 74, height: 32),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.isMovable = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        hostingController = NSHostingController(rootView: CapsuleOverlayView(state: .recording))
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 74, height: 32)
        panel.contentViewController = hostingController
    }

    func show(_ state: OverlayState, hidesAfter delay: TimeInterval? = nil) {
        hideWorkItem?.cancel()
        hostingController.rootView = CapsuleOverlayView(state: state)
        positionPanel()
        panel.orderFrontRegardless()

        if let delay {
            let workItem = DispatchWorkItem { [weak self] in
                self?.hide()
            }
            hideWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }

    func hide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        panel.orderOut(nil)
    }

    private func positionPanel() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let visibleFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let origin = CGPoint(
            x: visibleFrame.midX - panelSize.width / 2,
            y: visibleFrame.minY + 26
        )
        panel.setFrameOrigin(origin)
    }
}
