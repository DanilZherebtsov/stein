import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    init(state: AppStateStore) {
        let view = PreferencesView(state: state)
        let hosting = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: hosting)
        window.title = "Stein Preferences"
        window.setContentSize(NSSize(width: 760, height: 560))
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct PreferencesView: View {
    @ObservedObject var state: AppStateStore
    @State private var newGroupName: String = ""
    @State private var importMessage: String = ""

    private let iconOptions = [
        ("wineglass", "Wine Glass"),
        ("line.3.horizontal.decrease.circle", "Filter"),
        ("square.stack.3d.up", "Stack"),
        ("tray.full", "Tray"),
        ("folder.fill", "Folder"),
        ("ellipsis.circle", "Dots")
    ]

    private let shortcutOptions = ["⌥⌘B", "⌥⌘S", "⌥⌘H", "⌃⌥⌘B", "Disabled"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Stein")
                .font(.title2).bold()

            HStack(spacing: 16) {
                Toggle("Hide newly discovered items by default", isOn: Binding(
                    get: { state.state.preferences.hideNewItemsByDefault },
                    set: { state.setHideNewItemsByDefault($0) }
                ))

                Toggle("Start at login", isOn: Binding(
                    get: { state.state.preferences.launchAtLogin },
                    set: { state.setLaunchAtLogin($0) }
                ))

                Picker("Global shortcut", selection: Binding(
                    get: { state.state.preferences.globalToggleShortcut },
                    set: { state.setGlobalToggleShortcut($0) }
                )) {
                    ForEach(shortcutOptions, id: \.self) { shortcut in
                        Text(shortcut).tag(shortcut)
                    }
                }
                .frame(width: 180)
            }

            HStack {
                Text("Stein icon")
                Picker("Stein icon", selection: Binding(
                    get: { state.state.preferences.menuBarSymbolName },
                    set: { state.setMenuBarSymbol($0) }
                )) {
                    ForEach(iconOptions, id: \.0) { icon, label in
                        Label(label, systemImage: icon).tag(icon)
                    }
                }
                .frame(width: 260)
            }

            Divider()

            HStack {
                Text("Managed Items").font(.headline)
                Spacer()
                Button("Import Running Apps") {
                    let added = state.importRunningApplications()
                    importMessage = added > 0 ? "Imported \(added) app(s)." : "No new apps found to import."
                }
                .buttonStyle(.borderedProminent)
            }

            if !importMessage.isEmpty {
                Text(importMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            List {
                if state.state.items.isEmpty {
                    Text("No items yet. Click ‘Import Running Apps’ to add real apps.")
                        .foregroundStyle(.secondary)
                }

                ForEach(state.state.items) { item in
                    HStack {
                        Text(item.title)
                        Spacer()

                        Picker("Group", selection: Binding(
                            get: { item.groupId },
                            set: { state.assign(itemId: item.id, to: $0) }
                        )) {
                            Text("Ungrouped").tag(UUID?.none)
                            ForEach(state.state.groups) { group in
                                Text(group.title).tag(UUID?.some(group.id))
                            }
                        }
                        .frame(width: 170)

                        Toggle("Visible", isOn: Binding(
                            get: { item.isVisible },
                            set: { state.setVisibility(itemId: item.id, visible: $0) }
                        ))
                        .toggleStyle(.switch)
                        .frame(width: 86)
                    }
                }
            }

            HStack {
                TextField("New group name", text: $newGroupName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)

                Button("Add Group") {
                    state.addGroup(title: newGroupName.trimmingCharacters(in: .whitespacesAndNewlines), symbolName: "square.grid.2x2")
                    newGroupName = ""
                }
                .disabled(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
