import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

final class FnKeyMonitor {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    var triggerMode: TriggerMode = .fnHold {
        didSet { isTriggerPressed = false }
    }

    private(set) var isLocalMonitoringActive = false
    private(set) var isGlobalMonitoringActive = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var localMonitor: Any?
    private var isTriggerPressed = false

    deinit {
        stop()
    }

    @discardableResult
    func start(allowGlobalTap: Bool) -> Bool {
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                self?.handle(nsEvent: event)
                return event
            }
        }
        isLocalMonitoringActive = localMonitor != nil

        if allowGlobalTap {
            installGlobalTapIfNeeded()
        } else {
            teardownGlobalTap()
        }

        return isLocalMonitoringActive || isGlobalMonitoringActive
    }

    func stop() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        localMonitor = nil
        isLocalMonitoringActive = false
        teardownGlobalTap()
        isTriggerPressed = false
    }

    private func installGlobalTapIfNeeded() {
        guard eventTap == nil else {
            isGlobalMonitoringActive = true
            return
        }

        let eventMask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            return monitor.handle(proxy: proxy, type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            isGlobalMonitoringActive = false
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        isGlobalMonitoringActive = true
    }

    private func teardownGlobalTap() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        runLoopSource = nil
        eventTap = nil
        isGlobalMonitoringActive = false
    }

    private func handle(proxy _: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .flagsChanged else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let nextPressed = triggerPressedState(for: keyCode, flags: event.flags)
        processTransition(nextPressed: nextPressed)

        return Unmanaged.passUnretained(event)
    }

    private func handle(nsEvent: NSEvent) {
        let keyCode = Int(nsEvent.keyCode)
        let flags = CGEventFlags(rawValue: UInt64(nsEvent.modifierFlags.rawValue))
        let nextPressed = triggerPressedState(for: keyCode, flags: flags)
        processTransition(nextPressed: nextPressed)
    }

    private func triggerPressedState(for keyCode: Int, flags: CGEventFlags) -> Bool? {
        switch triggerMode {
        case .fnHold:
            guard keyCode == kVK_Function || flags.contains(.maskSecondaryFn) != isTriggerPressed else {
                return nil
            }
            return flags.contains(.maskSecondaryFn)
        case .rightCommandHold:
            guard keyCode == kVK_RightCommand || flags.contains(.maskCommand) != isTriggerPressed else {
                return nil
            }
            return keyCode == kVK_RightCommand && flags.contains(.maskCommand)
        case .rightOptionHold:
            guard keyCode == kVK_RightOption || flags.contains(.maskAlternate) != isTriggerPressed else {
                return nil
            }
            return keyCode == kVK_RightOption && flags.contains(.maskAlternate)
        }
    }

    private func processTransition(nextPressed: Bool?) {
        guard let nextPressed, nextPressed != isTriggerPressed else { return }

        isTriggerPressed = nextPressed
        DispatchQueue.main.async { [weak self] in
            if nextPressed {
                self?.onPress?()
            } else {
                self?.onRelease?()
            }
        }
    }
}
