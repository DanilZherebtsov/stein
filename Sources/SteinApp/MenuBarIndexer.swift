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
    private let hostBundleIDs = [
        "com.apple.systemuiserver",
        "com.apple.controlcenter",
        "com.apple.WindowManager"
    ]

    func accessibilityEnabled() -> Bool {
        AXIsProcessTrusted()
    }

    func ensureAccessibilityPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func indexMenuBarItems() -> [IndexedMenuBarItem] {
        var entries: [IndexedMenuBarItem] = []

        let roots = allMenuBarRoots()
        for root in roots {
            for element in menuBarCandidates(from: root) {
                var pid: pid_t = 0
                AXUIElementGetPid(element, &pid)
                guard pid != 0 else { continue }

                let title = readTitle(from: element, fallbackPID: Int32(pid))
                let identifier = stableIdentifier(for: element, fallbackTitle: title)
                let canToggle = canToggleVisibility(on: element)

                entries.append(
                    IndexedMenuBarItem(
                        title: title,
                        owningPID: Int32(pid),
                        axIdentifier: identifier,
                        canToggleVisibility: canToggle
                    )
                )
            }
        }

        // Fallback for menu-bar-only apps that do not expose clear AX menu-item nodes.
        entries.append(contentsOf: indexLikelyMenuBarApps())

        return Dictionary(grouping: entries, by: { "\($0.owningPID)::\($0.title.lowercased())" })
            .compactMap { $0.value.first }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    @discardableResult
    func setVisibility(for item: ManagedItem, visible: Bool) -> Bool {
        guard let pid = item.owningPID, let axIdentifier = item.axIdentifier else { return false }
        guard let element = findMenuBarItem(pid: pid, identifier: axIdentifier, fallbackTitle: item.title) else { return false }

        // 1) direct hidden attribute on candidate
        if setHidden(on: element, visible: visible) {
            return true
        }

        // 2) try immediate parent chain (some extras expose settable hidden only on ancestor)
        var current: AXUIElement? = element
        for _ in 0..<3 {
            guard let node = current, let parent = copyElementAttribute(node, attribute: kAXParentAttribute) else { break }
            if setHidden(on: parent, visible: visible) {
                return true
            }
            current = parent
        }

        return false
    }

    // MARK: - Discovery

    private func indexLikelyMenuBarApps() -> [IndexedMenuBarItem] {
        let blockedBundleIDs: Set<String> = [
            "com.apple.finder",
            "com.apple.dock",
            "com.apple.loginwindow",
            "com.apple.SystemUIServer",
            "com.apple.systemuiserver",
            "com.apple.controlcenter",
            "lab.agentfoundry.stein"
        ]

        let apps = NSWorkspace.shared.runningApplications.filter { app in
            guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return false }
            guard let bid = app.bundleIdentifier, !blockedBundleIDs.contains(bid) else { return false }
            guard app.activationPolicy == .accessory else { return false }

            // Preference: true menu-bar helper style apps (LSUIElement=1)
            if let bundleURL = app.bundleURL,
               let bundle = Bundle(url: bundleURL),
               let uiElement = bundle.object(forInfoDictionaryKey: "LSUIElement") as? Bool,
               uiElement {
                return true
            }

            // Fallback for helper apps that still use accessory policy.
            return true
        }

        return apps.compactMap { app in
            guard let name = app.localizedName, !name.isEmpty else { return nil }
            let bid = app.bundleIdentifier ?? "pid-\(app.processIdentifier)"
            return IndexedMenuBarItem(
                title: "\(name) menu item",
                owningPID: Int32(app.processIdentifier),
                axIdentifier: "app::\(bid)",
                canToggleVisibility: false
            )
        }
    }

    private func allMenuBarRoots() -> [AXUIElement] {
        let hosts = NSWorkspace.shared.runningApplications.filter { app in
            guard let bid = app.bundleIdentifier else { return false }
            return hostBundleIDs.contains(bid)
        }

        var roots: [AXUIElement] = []
        for app in hosts {
            let appAX = AXUIElementCreateApplication(app.processIdentifier)

            if let menuBar = copyElementAttribute(appAX, attribute: kAXMenuBarAttribute) {
                roots.append(menuBar)
            }

            // Some versions expose alternate menu-bar containers.
            for element in descendants(of: appAX, maxDepth: 3) where isLikelyMenuBarContainer(element) {
                roots.append(element)
            }
        }

        return roots
    }

    private func menuBarCandidates(from root: AXUIElement) -> [AXUIElement] {
        // Focus on top-level row first to avoid false positives from Control Center internals.
        let level1 = copyChildren(of: root) ?? []
        var candidates: [AXUIElement] = []

        for element in level1 {
            if isLikelyMenuExtra(element) {
                candidates.append(element)
                continue
            }

            // One additional nesting level catches grouped extras without traversing deep popovers.
            for child in (copyChildren(of: element) ?? []) where isLikelyMenuExtra(child) {
                candidates.append(child)
            }
        }

        return candidates
    }

    // MARK: - AX helpers

    private func descendants(of root: AXUIElement, maxDepth: Int) -> [AXUIElement] {
        var result: [AXUIElement] = []
        var queue: [(AXUIElement, Int)] = [(root, 0)]

        while !queue.isEmpty {
            let (element, depth) = queue.removeFirst()
            result.append(element)
            guard depth < maxDepth else { continue }

            if let children = copyChildren(of: element) {
                for child in children { queue.append((child, depth + 1)) }
            }
        }

        return result
    }

    private func copyChildren(of element: AXUIElement) -> [AXUIElement]? {
        var ref: CFTypeRef?
        let r = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &ref)
        guard r == .success, let ref else { return nil }
        return ref as? [AXUIElement]
    }

    private func copyElementAttribute(_ element: AXUIElement, attribute: String) -> AXUIElement? {
        var ref: CFTypeRef?
        let r = AXUIElementCopyAttributeValue(element, attribute as CFString, &ref)
        guard r == .success, let ref else { return nil }
        return ref as? AXUIElement
    }

    private func isLikelyMenuBarContainer(_ element: AXUIElement) -> Bool {
        let role = readStringAttr(kAXRoleAttribute, from: element).lowercased()
        let subrole = readStringAttr(kAXSubroleAttribute, from: element).lowercased()
        return role.contains("menubar") || subrole.contains("menubar")
    }

    private func isLikelyMenuExtra(_ element: AXUIElement) -> Bool {
        let role = readStringAttr(kAXRoleAttribute, from: element).lowercased()
        let subrole = readStringAttr(kAXSubroleAttribute, from: element).lowercased()

        if role.contains("menubaritem") || subrole.contains("menubarextra") {
            return true
        }

        if role.contains("button") {
            let identifier = readStringAttr(kAXIdentifierAttribute, from: element).lowercased()
            return identifier.contains("status") || identifier.contains("menu") || identifier.contains("extra")
        }

        return false
    }

    private func readTitle(from element: AXUIElement, fallbackPID: Int32) -> String {
        for key in [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute] {
            let value = readStringAttr(key, from: element).trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { return value }
        }

        if let app = NSRunningApplication(processIdentifier: fallbackPID),
           let appName = app.localizedName,
           !appName.isEmpty {
            return "\(appName) menu item"
        }

        return "Menu item \(fallbackPID)"
    }

    private func readStringAttr(_ attribute: String, from element: AXUIElement) -> String {
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
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

    private func canToggleVisibility(on element: AXUIElement) -> Bool {
        if isHiddenSettable(on: element) { return true }

        var current: AXUIElement? = element
        for _ in 0..<3 {
            guard let node = current, let parent = copyElementAttribute(node, attribute: kAXParentAttribute) else { break }
            if isHiddenSettable(on: parent) { return true }
            current = parent
        }

        return false
    }

    private func isHiddenSettable(on element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        let result = AXUIElementIsAttributeSettable(element, kAXHiddenAttribute as CFString, &settable)
        return result == .success && settable.boolValue
    }

    private func setHidden(on element: AXUIElement, visible: Bool) -> Bool {
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(element, kAXHiddenAttribute as CFString, &settable) == .success,
              settable.boolValue else { return false }

        let value: CFBoolean = visible ? kCFBooleanFalse : kCFBooleanTrue
        return AXUIElementSetAttributeValue(element, kAXHiddenAttribute as CFString, value) == .success
    }

    private func findMenuBarItem(pid: Int32, identifier: String, fallbackTitle: String) -> AXUIElement? {
        for root in allMenuBarRoots() {
            for element in menuBarCandidates(from: root) {
                var childPID: pid_t = 0
                AXUIElementGetPid(element, &childPID)
                guard Int32(childPID) == pid else { continue }

                let ident = stableIdentifier(for: element, fallbackTitle: readTitle(from: element, fallbackPID: Int32(childPID)))
                if ident == identifier { return element }
            }

            if let fallback = menuBarCandidates(from: root).first(where: { element in
                var childPID: pid_t = 0
                AXUIElementGetPid(element, &childPID)
                guard Int32(childPID) == pid else { return false }
                return readTitle(from: element, fallbackPID: Int32(childPID)).caseInsensitiveCompare(fallbackTitle) == .orderedSame
            }) {
                return fallback
            }
        }

        return nil
    }
}
