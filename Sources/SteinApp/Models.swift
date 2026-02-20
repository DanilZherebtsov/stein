import Foundation

struct ManagedItem: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var isVisible: Bool
    var groupId: UUID?

    init(id: UUID = UUID(), title: String, isVisible: Bool = true, groupId: UUID? = nil) {
        self.id = id
        self.title = title
        self.isVisible = isVisible
        self.groupId = groupId
    }
}

struct ItemGroup: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var symbolName: String

    init(id: UUID = UUID(), title: String, symbolName: String = "square.grid.2x2") {
        self.id = id
        self.title = title
        self.symbolName = symbolName
    }
}

struct AppPreferences: Codable {
    var showsManagedItems: Bool
    var hideNewItemsByDefault: Bool
    var menuBarSymbolName: String
    var globalToggleShortcut: String

    static let `default` = AppPreferences(
        showsManagedItems: true,
        hideNewItemsByDefault: false,
        menuBarSymbolName: "wineglass",
        globalToggleShortcut: "⌥⌘B"
    )
}

struct PersistedState: Codable {
    var preferences: AppPreferences
    var groups: [ItemGroup]
    var items: [ManagedItem]

    static let initial = PersistedState(
        preferences: .default,
        groups: [
            ItemGroup(title: "Utilities", symbolName: "wrench.and.screwdriver"),
            ItemGroup(title: "Comms", symbolName: "message")
        ],
        items: [
            ManagedItem(title: "Wi‑Fi", isVisible: true),
            ManagedItem(title: "Battery", isVisible: true),
            ManagedItem(title: "VPN", isVisible: false),
            ManagedItem(title: "Clipboard", isVisible: false)
        ]
    )
}
