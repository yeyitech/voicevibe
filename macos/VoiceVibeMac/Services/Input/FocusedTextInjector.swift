import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

struct FocusedInputTarget {
    let focusedElement: AXUIElement
    let applicationElement: AXUIElement?
    let runningApplication: NSRunningApplication?
    let applicationName: String
    let bundleIdentifier: String?
    let role: String?

    var summary: String {
        [
            applicationName,
            role
        ]
        .compactMap { $0?.nilIfBlank }
        .joined(separator: " · ")
    }
}

enum TextInjectionStrategy: String {
    case accessibilityValue
    case pasteboardPaste
    case syntheticTyping

    var displayName: String {
        switch self {
        case .accessibilityValue:
            return "AX 直写"
        case .pasteboardPaste:
            return "剪贴板粘贴"
        case .syntheticTyping:
            return "模拟键盘输入"
        }
    }
}

enum TextInjectionError: LocalizedError {
    case accessibilityUnavailable
    case noFocusedInput
    case appInternalInput
    case unreadableValue
    case unsupportedTarget
    case updateFailed(AXError)
    case eventPostingUnavailable
    case failedToCreateEventSource

    var errorDescription: String? {
        switch self {
        case .accessibilityUnavailable:
            return "需要辅助功能权限才能锁定并写入目标输入框。"
        case .noFocusedInput:
            return "开始录音时没有找到可写入的输入目标。"
        case .appInternalInput:
            return "当前焦点在 VoiceVibe 自己的输入框里，已跳过自动锁定。"
        case .unreadableValue:
            return "当前输入目标不支持读取文本值。"
        case .unsupportedTarget:
            return "当前输入目标不支持直接写入。"
        case .updateFailed(let error):
            return "更新输入目标失败：\(error.rawValue)"
        case .eventPostingUnavailable:
            return "缺少 Post Events 权限，无法执行键盘输入回退。"
        case .failedToCreateEventSource:
            return "无法创建键盘事件源。"
        }
    }
}

final class FocusedTextInjector {
    private let appBundleIdentifier = "com.psyhitech.voicevibe.mac"

    func captureFocusedInputTarget() throws -> FocusedInputTarget {
        guard AXIsProcessTrusted() else {
            throw TextInjectionError.accessibilityUnavailable
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedObject: CFTypeRef?
        let focusedError = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedObject
        )

        guard focusedError == .success, let focusedObject else {
            throw TextInjectionError.noFocusedInput
        }
        guard CFGetTypeID(focusedObject) == AXUIElementGetTypeID() else {
            throw TextInjectionError.noFocusedInput
        }

        let focusedElement = unsafeBitCast(focusedObject, to: AXUIElement.self)

        let runningApplication = NSWorkspace.shared.frontmostApplication
        let applicationElement = runningApplication.map { AXUIElementCreateApplication($0.processIdentifier) }
        let role = try? stringAttribute(kAXRoleAttribute as CFString, of: focusedElement)

        if runningApplication?.bundleIdentifier == appBundleIdentifier {
            throw TextInjectionError.appInternalInput
        }

        return FocusedInputTarget(
            focusedElement: focusedElement,
            applicationElement: applicationElement,
            runningApplication: runningApplication,
            applicationName: runningApplication?.localizedName ?? "未知应用",
            bundleIdentifier: runningApplication?.bundleIdentifier,
            role: role
        )
    }

    func insert(text: String, into target: FocusedInputTarget) throws -> TextInjectionStrategy {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else { return .accessibilityValue }

        do {
            try insertViaAccessibility(text: normalizedText, into: target)
            return .accessibilityValue
        } catch {
        }

        do {
            try insertViaPasteboardPaste(text: normalizedText, into: target)
            return .pasteboardPaste
        } catch {
        }

        try insertViaSyntheticTyping(text: normalizedText, into: target)
        return .syntheticTyping
    }

    private func insertViaAccessibility(text: String, into target: FocusedInputTarget) throws {
        let currentValue = try currentStringValue(of: target.focusedElement)
        let currentNSString = currentValue as NSString
        let selectedRange = try currentSelectedRange(of: target.focusedElement, fallbackLength: currentNSString.length)

        var isSettable = DarwinBoolean(false)
        let settableError = AXUIElementIsAttributeSettable(
            target.focusedElement,
            kAXValueAttribute as CFString,
            &isSettable
        )
        guard settableError == .success, isSettable.boolValue else {
            throw TextInjectionError.unsupportedTarget
        }

        let safeRange = sanitized(range: selectedRange, maxLength: currentNSString.length)
        let insertedLength = (text as NSString).length
        let nextValue = currentNSString.replacingCharacters(
            in: NSRange(location: safeRange.location, length: safeRange.length),
            with: text
        ) as NSString

        let setValueError = AXUIElementSetAttributeValue(
            target.focusedElement,
            kAXValueAttribute as CFString,
            nextValue
        )
        guard setValueError == .success else {
            throw TextInjectionError.updateFailed(setValueError)
        }

        var nextSelection = CFRange(location: safeRange.location + insertedLength, length: 0)
        if let rangeValue = AXValueCreate(.cfRange, &nextSelection) {
            _ = AXUIElementSetAttributeValue(
                target.focusedElement,
                kAXSelectedTextRangeAttribute as CFString,
                rangeValue
            )
        }
    }

    private func insertViaSyntheticTyping(text: String, into target: FocusedInputTarget) throws {
        try ensureEventPostingAccess()
        activate(target)
        let eventSource = try makeEventSource()

        for character in text {
            let scalars = Array(String(character).utf16)

            guard
                let keyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: true),
                let keyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: false)
            else {
                continue
            }

            scalars.withUnsafeBufferPointer { buffer in
                guard let address = buffer.baseAddress else { return }
                keyDown.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: address)
                keyUp.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: address)
            }

            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
    }

    private func insertViaPasteboardPaste(text: String, into target: FocusedInputTarget) throws {
        try ensureEventPostingAccess()

        let pasteboard = NSPasteboard.general
        let snapshot = capturePasteboardSnapshot(from: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        defer {
            restorePasteboardSnapshot(snapshot, to: pasteboard)
        }

        activate(target)
        let eventSource = try makeEventSource()

        guard
            let keyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        else {
            throw TextInjectionError.failedToCreateEventSource
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        Thread.sleep(forTimeInterval: 0.12)
    }

    private func currentStringValue(of element: AXUIElement) throws -> String {
        var rawValue: CFTypeRef?
        let valueError = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &rawValue)
        guard valueError == .success else {
            throw TextInjectionError.unreadableValue
        }

        if let stringValue = rawValue as? String {
            return stringValue
        }

        if let attributedValue = rawValue as? NSAttributedString {
            return attributedValue.string
        }

        throw TextInjectionError.unreadableValue
    }

    private func currentSelectedRange(of element: AXUIElement, fallbackLength: Int) throws -> CFRange {
        var rawValue: CFTypeRef?
        let rangeError = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rawValue
        )

        guard rangeError == .success, let rawValue else {
            return CFRange(location: fallbackLength, length: 0)
        }
        guard CFGetTypeID(rawValue) == AXValueGetTypeID() else {
            return CFRange(location: fallbackLength, length: 0)
        }

        let axValue = unsafeBitCast(rawValue, to: AXValue.self)
        var range = CFRange()
        let success = AXValueGetValue(axValue, .cfRange, &range)
        return success ? range : CFRange(location: fallbackLength, length: 0)
    }

    private func stringAttribute(_ attribute: CFString, of element: AXUIElement) throws -> String? {
        var rawValue: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute, &rawValue)
        guard error == .success else { return nil }

        if let stringValue = rawValue as? String {
            return stringValue
        }

        if let attributedValue = rawValue as? NSAttributedString {
            return attributedValue.string
        }

        return nil
    }

    private func ensureEventPostingAccess() throws {
        guard CGPreflightPostEventAccess() else {
            throw TextInjectionError.eventPostingUnavailable
        }
    }

    private func activate(_ target: FocusedInputTarget) {
        target.runningApplication?.activate()
        Thread.sleep(forTimeInterval: 0.08)
    }

    private func makeEventSource() throws -> CGEventSource {
        guard let eventSource = CGEventSource(stateID: .combinedSessionState) else {
            throw TextInjectionError.failedToCreateEventSource
        }
        return eventSource
    }

    private func capturePasteboardSnapshot(from pasteboard: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        guard let items = pasteboard.pasteboardItems else { return [] }

        return items.map { item in
            Dictionary(
                uniqueKeysWithValues: item.types.compactMap { type in
                    item.data(forType: type).map { (type, $0) }
                }
            )
        }
    }

    private func restorePasteboardSnapshot(_ snapshot: [[NSPasteboard.PasteboardType: Data]], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !snapshot.isEmpty else { return }

        let items = snapshot.map { itemData -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in itemData {
                item.setData(data, forType: type)
            }
            return item
        }

        pasteboard.writeObjects(items)
    }

    private func sanitized(range: CFRange, maxLength: Int) -> CFRange {
        let location = min(max(range.location, 0), maxLength)
        let upperBound = min(location + max(range.length, 0), maxLength)
        return CFRange(location: location, length: upperBound - location)
    }
}
