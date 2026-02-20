import AppKit

final class StatusItemController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let state: AppStateStore
    private let onOpenPreferences: () -> Void

    init(state: AppStateStore, onOpenPreferences: @escaping () -> Void) {
        self.state = state
        self.onOpenPreferences = onOpenPreferences
        rebuildMenu()
    }

    private func setIcon() {
        let symbol = state.state.preferences.menuBarSymbolName
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Stein")
        statusItem.button?.imagePosition = .imageOnly
    }

    func refresh() {
        rebuildMenu()
    }

    private func rebuildMenu() {
        setIcon()

        let menu = NSMenu()
        menu.addItem(withTitle: "Toggle Managed Items", action: #selector(toggleManagedItems), keyEquivalent: "t").target = self
        menu.addItem(NSMenuItem.separator())

        for group in state.state.groups {
            let submenuItem = NSMenuItem(title: group.title, action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for item in state.state.items.filter({ $0.groupId == group.id }) {
                let entry = NSMenuItem(title: item.title, action: #selector(toggleSingleItem(_:)), keyEquivalent: "")
                entry.representedObject = item.id.uuidString
                entry.state = item.isVisible ? .on : .off
                entry.target = self
                submenu.addItem(entry)
            }
            if submenu.items.isEmpty {
                let empty = NSMenuItem(title: "No items", action: nil, keyEquivalent: "")
                empty.isEnabled = false
                submenu.addItem(empty)
            }
            submenuItem.submenu = submenu
            menu.addItem(submenuItem)
        }

        let ungrouped = state.state.items.filter { $0.groupId == nil }
        if !ungrouped.isEmpty {
            menu.addItem(NSMenuItem.separator())
            for item in ungrouped {
                let entry = NSMenuItem(title: item.title, action: #selector(toggleSingleItem(_:)), keyEquivalent: "")
                entry.representedObject = item.id.uuidString
                entry.state = item.isVisible ? .on : .off
                entry.target = self
                menu.addItem(entry)
            }
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Quit Stein", action: #selector(quit), keyEquivalent: "q").target = self

        statusItem.menu = menu
    }

    func triggerGlobalToggle() {
        state.toggleAllManagedItems()
        rebuildMenu()
    }

    @objc private func toggleManagedItems() {
        triggerGlobalToggle()
    }

    @objc private func toggleSingleItem(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let id = UUID(uuidString: raw) else { return }
        let next = sender.state != .on
        state.setVisibility(itemId: id, visible: next)
        rebuildMenu()
    }

    @objc private func openPreferences() {
        onOpenPreferences()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
