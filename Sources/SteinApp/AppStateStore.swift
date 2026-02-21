import Foundation
import AppKit

extension Notification.Name {
    static let steinStateDidChange = Notification.Name("steinStateDidChange")
}

final class AppStateStore: ObservableObject {
    private let fileURL: URL
    private let menuBarIndexer = MenuBarIndexer()

    @Published private(set) var state: PersistedState {
        didSet {
            save()
            NotificationCenter.default.post(name: .steinStateDidChange, object: nil)
        }
    }

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Stein", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("state.json")

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(PersistedState.self, from: data) {
            state = decoded
        } else {
            state = .initial
            save()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: fileURL)
        }
    }

    func accessibilityEnabled() -> Bool {
        menuBarIndexer.accessibilityEnabled()
    }

    func requestAccessibilityPermission() {
        menuBarIndexer.ensureAccessibilityPrompt()
    }

    func toggleAllManagedItems() {
        state.preferences.showsManagedItems.toggle()
        let shouldShow = state.preferences.showsManagedItems

        state.items = state.items.map { item in
            var next = item
            if next.canToggleSystemVisibility {
                let applied = menuBarIndexer.setVisibility(for: next, visible: shouldShow)
                if applied {
                    next.isVisible = shouldShow
                } else {
                    next.canToggleSystemVisibility = false
                }
            } else {
                next.isVisible = shouldShow
            }
            return next
        }
    }

    func setMenuBarSymbol(_ symbol: String) {
        state.preferences.menuBarSymbolName = symbol
    }

    func setGlobalToggleShortcut(_ shortcut: String) {
        state.preferences.globalToggleShortcut = shortcut
    }

    func setHideNewItemsByDefault(_ value: Bool) {
        state.preferences.hideNewItemsByDefault = value
    }

    func setLaunchAtLogin(_ value: Bool) {
        state.preferences.launchAtLogin = value
    }

    func setVisibility(itemId: UUID, visible: Bool) {
        guard let index = state.items.firstIndex(where: { $0.id == itemId }) else { return }
        let item = state.items[index]

        if item.canToggleSystemVisibility {
            let applied = menuBarIndexer.setVisibility(for: item, visible: visible)
            if applied {
                state.items[index].isVisible = visible
            } else {
                state.items[index].canToggleSystemVisibility = false
            }
        } else {
            state.items[index].isVisible = visible
        }
    }

    func assign(itemId: UUID, to groupId: UUID?) {
        guard let index = state.items.firstIndex(where: { $0.id == itemId }) else { return }
        state.items[index].groupId = groupId
    }

    func addItem(title: String) {
        guard !title.isEmpty else { return }
        let exists = state.items.contains { $0.title.caseInsensitiveCompare(title) == .orderedSame }
        guard !exists else { return }
        let item = ManagedItem(title: title, isVisible: !state.preferences.hideNewItemsByDefault)
        state.items.append(item)
    }

    @discardableResult
    func importMenuBarItems() -> Int {
        if !menuBarIndexer.accessibilityEnabled() {
            menuBarIndexer.ensureAccessibilityPrompt()
            return 0
        }

        let indexed = menuBarIndexer.indexMenuBarItems()
        let existing = Set(state.items.compactMap { item -> String? in
            guard let pid = item.owningPID else { return nil }
            return "\(pid)::\(item.title.lowercased())"
        })

        // Refresh metadata for already-indexed items.
        for entry in indexed {
            if let idx = state.items.firstIndex(where: {
                $0.owningPID == entry.owningPID && $0.title.caseInsensitiveCompare(entry.title) == .orderedSame
            }) {
                state.items[idx].axIdentifier = entry.axIdentifier
                state.items[idx].canToggleSystemVisibility = entry.canToggleVisibility
            }
        }

        let newItems = indexed.filter { !existing.contains("\($0.owningPID)::\($0.title.lowercased())") }
        for entry in newItems {
            let item = ManagedItem(
                title: entry.title,
                isVisible: !state.preferences.hideNewItemsByDefault,
                owningPID: entry.owningPID,
                axIdentifier: entry.axIdentifier,
                canToggleSystemVisibility: entry.canToggleVisibility
            )
            state.items.append(item)
        }
        return newItems.count
    }

    func addGroup(title: String, symbolName: String) {
        guard !title.isEmpty else { return }
        state.groups.append(ItemGroup(title: title, symbolName: symbolName))
    }
}
