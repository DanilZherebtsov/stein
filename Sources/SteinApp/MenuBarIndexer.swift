import Foundation
import AppKit
import ApplicationServices

struct IndexedMenuBarItem {
    let title: String
    let owningPID: Int32
    let axIdentifier: String
    let canToggleVisibility: Bool
}

final class MenuBarIndexer {
    func accessibilityEnabled() -> Bool {
        AXIsProcessTrusted()
    }

    func ensureAccessibilityPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func indexMenuBarItems() -> [IndexedMenuBarItem] {
        guard let frontBar = findSystemMenuBarElement() else { return [] }

        var childrenRef: CFArray?
        let result = AXUIElementCopyAttributeValue(frontBar, kAXChildrenAttribute as CFString, &childrenRef)
        guard result == .success, let children = childrenRef as? [AXUIElement] else { return [] }

        var entries: [IndexedMenuBarItem] = []

        for child in children {
            var pid: pid_t = 0
            AXUIElementGetPid(child, &pid)

            let title = readTitle(from: child)
            if title.isEmpty { continue }

            let identifier = stableIdentifier(for: child, fallbackTitle: title)
            let canToggle = isHiddenSettable(on: child)

            entries.append(
                IndexedMenuBarItem(
                    title: title,
                    owningPID: Int32(pid),
                    axIdentifier: identifier,
                    canToggleVisibility: canToggle
                )
            )
        }

        // Deduplicate by title + pid
        let deduped = Dictionary(grouping: entries, by: { "\($0.owningPID)::\($0.title.lowercased())" })
            .compactMap { $0.value.first }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        return deduped
    }

    func setVisibility(for item: ManagedItem, visible: Bool) {
        guard let pid = item.owningPID, let axIdentifier = item.axIdentifier else { return }
        guard let element = findMenuBarItem(pid: pid, identifier: axIdentifier, fallbackTitle: item.title) else { return }

        let value = visible ? kCFBooleanFalse : kCFBooleanTrue
        _ = AXUIElementSetAttributeValue(element, kAXHiddenAttribute as CFString, value)
    }

    // MARK: - AX helpers

    private func findSystemMenuBarElement() -> AXUIElement? {
        let running = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "com.apple.systemuiserver" }
        guard let pid = running?.processIdentifier else { return nil }

        let app = AXUIElementCreateApplication(pid)
        var menuBarRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &menuBarRef)
        guard result == .success, let menuBar = (menuBarRef as! AXUIElement?) else { return nil }
        return menuBar
    }

    private func readTitle(from element: AXUIElement) -> String {
        for key in [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute] {
            var value: CFTypeRef?
            let r = AXUIElementCopyAttributeValue(element, key as CFString, &value)
            if r == .success, let str = value as? String, !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return str.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return ""
    }

    private func stableIdentifier(for element: AXUIElement, fallbackTitle: String) -> String {
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &value) == .success,
           let id = value as? String,
           !id.isEmpty {
            return id
        }

        var role: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        let roleStr = (role as? String) ?? "unknown"
        return "\(roleStr)::\(fallbackTitle.lowercased())"
    }

    private func isHiddenSettable(on element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        let result = AXUIElementIsAttributeSettable(element, kAXHiddenAttribute as CFString, &settable)
        return result == .success && settable.boolValue
    }

    private func findMenuBarItem(pid: Int32, identifier: String, fallbackTitle: String) -> AXUIElement? {
        guard let menuBar = findSystemMenuBarElement() else { return nil }
        var childrenRef: CFArray?
        let result = AXUIElementCopyAttributeValue(menuBar, kAXChildrenAttribute as CFString, &childrenRef)
        guard result == .success, let children = childrenRef as? [AXUIElement] else { return nil }

        for child in children {
            var childPID: pid_t = 0
            AXUIElementGetPid(child, &childPID)
            guard Int32(childPID) == pid else { continue }

            let ident = stableIdentifier(for: child, fallbackTitle: readTitle(from: child))
            if ident == identifier { return child }
        }

        return children.first(where: { element in
            var childPID: pid_t = 0
            AXUIElementGetPid(element, &childPID)
            guard Int32(childPID) == pid else { return false }
            return readTitle(from: element).caseInsensitiveCompare(fallbackTitle) == .orderedSame
        })
    }
}
