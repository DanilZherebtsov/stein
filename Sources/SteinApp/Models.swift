import Foundation

struct ManagedItem: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var isVisible: Bool
    var groupId: UUID?

    // Accessibility linkage for real menu-bar items
    var owningPID: Int32?
    var axIdentifier: String?
    var canToggleSystemVisibility: Bool

    init(
        id: UUID = UUID(),
        title: String,
        isVisible: Bool = true,
        groupId: UUID? = nil,
        owningPID: Int32? = nil,
        axIdentifier: String? = nil,
        canToggleSystemVisibility: Bool = false
    ) {
        self.id = id
        self.title = title
        self.isVisible = isVisible
        self.groupId = groupId
        self.owningPID = owningPID
        self.axIdentifier = axIdentifier
        self.canToggleSystemVisibility = canToggleSystemVisibility
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
    var launchAtLogin: Bool

    static let `default` = AppPreferences(
        showsManagedItems: true,
        hideNewItemsByDefault: false,
        menuBarSymbolName: "wineglass",
        globalToggleShortcut: "⌥⌘B",
        launchAtLogin: false
    )
}

struct PersistedState: Codable {
    var preferences: AppPreferences
    var groups: [ItemGroup]
    var items: [ManagedItem]

    static let initial = PersistedState(
        preferences: .default,
        groups: [],
        items: []
    )
}
