import Foundation

final class AppStateStore {
    private let fileURL: URL
    private(set) var state: PersistedState {
        didSet { save() }
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

    func setHideNewItemsByDefault(_ value: Bool) {
        state.preferences.hideNewItemsByDefault = value
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
        let item = ManagedItem(title: title, isVisible: !state.preferences.hideNewItemsByDefault)
        state.items.append(item)
    }

    func addGroup(title: String, symbolName: String) {
        state.groups.append(ItemGroup(title: title, symbolName: symbolName))
    }
}
