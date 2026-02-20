import Foundation
import AppKit

extension Notification.Name {
    static let steinStateDidChange = Notification.Name("steinStateDidChange")
}

final class AppStateStore: ObservableObject {
    private let fileURL: URL
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

    func toggleAllManagedItems() {
        state.preferences.showsManagedItems.toggle()
        let shouldShow = state.preferences.showsManagedItems
        state.items = state.items.map { item in
            var next = item
            next.isVisible = shouldShow
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
        state.items[index].isVisible = visible
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
    func importRunningApplications() -> Int {
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap(\.localizedName)
            .filter { !$0.isEmpty }

        let existing = Set(state.items.map { $0.title.lowercased() })
        let newTitles = Array(Set(apps.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }))
            .filter { !existing.contains($0.lowercased()) }
            .sorted()

        for title in newTitles {
            addItem(title: title)
        }

        return newTitles.count
    }

    func addGroup(title: String, symbolName: String) {
        guard !title.isEmpty else { return }
        state.groups.append(ItemGroup(title: title, symbolName: symbolName))
    }
}
