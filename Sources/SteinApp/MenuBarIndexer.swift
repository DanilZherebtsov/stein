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
        guard let menuBar = findSystemMenuBarElement() else { return [] }

        let candidates = descendants(of: menuBar, maxDepth: 6)
        var entries: [IndexedMenuBarItem] = []

        for element in candidates where isLikelyMenuExtra(element) {
            var pid: pid_t = 0
            AXUIElementGetPid(element, &pid)
            guard pid != 0 else { continue }

            let title = readTitle(from: element, fallbackPID: Int32(pid))
            if title.isEmpty { continue }

            let identifier = stableIdentifier(for: element, fallbackTitle: title)
            let canToggle = isHiddenSettable(on: element)

            entries.append(
                IndexedMenuBarItem(
                    title: title,
                    owningPID: Int32(pid),
                    axIdentifier: identifier,
                    canToggleVisibility: canToggle
                )
            )
        }

        // Deduplicate by pid/title and keep stable sort.
        let deduped = Dictionary(grouping: entries, by: { "\($0.owningPID)::\($0.title.lowercased())" })
            .compactMap { $0.value.first }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        return deduped
    }

    func setVisibility(for item: ManagedItem, visible: Bool) {
        guard let pid = item.owningPID, let axIdentifier = item.axIdentifier else { return }
        guard let element = findMenuBarItem(pid: pid, identifier: axIdentifier, fallbackTitle: item.title) else { return }

        let value: CFBoolean = visible ? kCFBooleanFalse : kCFBooleanTrue
        _ = AXUIElementSetAttributeValue(element, kAXHiddenAttribute as CFString, value)
    }

    // MARK: - AX helpers

    private func findSystemMenuBarElement() -> AXUIElement? {
        let running = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "com.apple.systemuiserver" }
        guard let pid = running?.processIdentifier else { return nil }

        let app = AXUIElementCreateApplication(pid)

        var menuBarRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &menuBarRef)
        guard result == .success, let menuBar = menuBarRef as? AXUIElement else { return nil }
        return menuBar
    }

    private func descendants(of root: AXUIElement, maxDepth: Int) -> [AXUIElement] {
        var result: [AXUIElement] = []
        var queue: [(AXUIElement, Int)] = [(root, 0)]

        while !queue.isEmpty {
            let (element, depth) = queue.removeFirst()
            result.append(element)
            guard depth < maxDepth else { continue }

            var childrenRef: CFTypeRef?
            let r = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
            if r == .success, let children = childrenRef as? [AXUIElement] {
                for child in children {
                    queue.append((child, depth + 1))
                }
            }
        }

        return result
    }

    private func isLikelyMenuExtra(_ element: AXUIElement) -> Bool {
        let role = readStringAttr(kAXRoleAttribute, from: element).lowercased()
        let subrole = readStringAttr(kAXSubroleAttribute, from: element).lowercased()

        if role.contains("menubaritem") || subrole.contains("menubarextra") {
            return true
        }

        // Tahoe/Sequoia variants sometimes expose extras as buttons under menu bar containers.
        if role.contains("button") {
            let identifier = readStringAttr(kAXIdentifierAttribute, from: element).lowercased()
            let desc = readStringAttr(kAXDescriptionAttribute, from: element).lowercased()
            if identifier.contains("status") || identifier.contains("menu") || desc.contains("menu") {
                return true
            }
        }

        return false
    }

    private func readTitle(from element: AXUIElement, fallbackPID: Int32) -> String {
        for key in [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute] {
            let value = readStringAttr(key, from: element).trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { return value }
        }

        if let app = NSRunningApplication(processIdentifier: fallbackPID) {
            return app.localizedName ?? "Menu Item \(fallbackPID)"
        }
        return ""
    }

    private func readStringAttr(_ attribute: CFString, from element: AXUIElement) -> String {
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
           let str = value as? String {
            return str
        }
        return ""
    }

    private func stableIdentifier(for element: AXUIElement, fallbackTitle: String) -> String {
        let id = readStringAttr(kAXIdentifierAttribute, from: element)
        if !id.isEmpty { return id }

        let role = readStringAttr(kAXRoleAttribute, from: element)
        return "\(role)::\(fallbackTitle.lowercased())"
    }

    private func isHiddenSettable(on element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        let result = AXUIElementIsAttributeSettable(element, kAXHiddenAttribute as CFString, &settable)
        return result == .success && settable.boolValue
    }

    private func findMenuBarItem(pid: Int32, identifier: String, fallbackTitle: String) -> AXUIElement? {
        guard let menuBar = findSystemMenuBarElement() else { return nil }
        let candidates = descendants(of: menuBar, maxDepth: 6)

        for element in candidates where isLikelyMenuExtra(element) {
            var childPID: pid_t = 0
            AXUIElementGetPid(element, &childPID)
            guard Int32(childPID) == pid else { continue }

            let ident = stableIdentifier(for: element, fallbackTitle: readTitle(from: element, fallbackPID: Int32(childPID)))
            if ident == identifier { return element }
        }

        return candidates.first(where: { element in
            guard isLikelyMenuExtra(element) else { return false }
            var childPID: pid_t = 0
            AXUIElementGetPid(element, &childPID)
            guard Int32(childPID) == pid else { return false }
            return readTitle(from: element, fallbackPID: Int32(childPID)).caseInsensitiveCompare(fallbackTitle) == .orderedSame
        })
    }
}
