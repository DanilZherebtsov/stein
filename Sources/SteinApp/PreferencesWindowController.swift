import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    init(state: AppStateStore) {
        let view = PreferencesView(state: state)
        let hosting = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: hosting)
        window.title = "Stein Preferences"
        window.setContentSize(NSSize(width: 920, height: 620))
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private enum PreferencesSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case items = "Items"
    case groups = "Groups"
    case shortcuts = "Shortcuts"
    case settings = "Settings"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .items: return "menubar.rectangle"
        case .groups: return "square.stack.3d.up.fill"
        case .shortcuts: return "command"
        case .settings: return "gearshape.fill"
        }
    }
}

struct PreferencesView: View {
    @ObservedObject var state: AppStateStore
    @State private var selected: PreferencesSection = .dashboard
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
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Stein")
                .font(.title2.bold())
                .padding(.horizontal, 14)
                .padding(.top, 12)

            ForEach(PreferencesSection.allCases) { section in
                Button {
                    selected = section
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: section.symbol)
                            .frame(width: 18)
                        Text(section.rawValue)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(selected == section ? Color.accentColor.opacity(0.25) : Color.clear)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
            }

            Spacer()
        }
        .frame(width: 210)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var detail: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch selected {
            case .dashboard:
                dashboardSection
            case .items:
                itemsSection
            case .groups:
                groupsSection
            case .shortcuts:
                shortcutsSection
            case .settings:
                settingsSection
            }
            Spacer()
        }
        .padding(20)
    }

    private var dashboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dashboard").font(.title2.bold())
            infoCard(title: "Overview") {
                HStack {
                    stat(label: "Managed Items", value: "\(state.state.items.count)")
                    stat(label: "Groups", value: "\(state.state.groups.count)")
                    stat(label: "Visible", value: "\(state.state.items.filter { $0.isVisible }.count)")
                }
            }

            HStack(spacing: 10) {
                Button("Index Menu Bar Items") {
                    let added = state.importMenuBarItems()
                    if !state.accessibilityEnabled() {
                        importMessage = "Accessibility permission is required. Open System Settings → Privacy & Security → Accessibility and enable Stein, then retry."
                    } else {
                        importMessage = added > 0 ? "Indexed \(added) new menu bar item(s)." : "No new menu bar items found."
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Toggle All Items") {
                    state.toggleAllManagedItems()
                }
                .buttonStyle(.bordered)
            }

            if !importMessage.isEmpty {
                Text(importMessage).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Items").font(.title2.bold())
            infoCard(title: "Managed Items") {
                VStack(spacing: 8) {
                    HStack {
                        Text("Item").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("Group").font(.caption).foregroundStyle(.secondary)
                            .frame(width: 170, alignment: .leading)
                        Text("Hide").font(.caption).foregroundStyle(.secondary)
                            .frame(width: 86, alignment: .leading)
                    }

                    List {
                        if state.state.items.isEmpty {
                            Text("No indexed items yet. Click ‘Index Menu Bar Items’ on Dashboard.")
                                .foregroundStyle(.secondary)
                        }

                        ForEach(state.state.items) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                    Text(item.canToggleSystemVisibility ? "System-hide supported" : "Proxy mode (no native hide)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()

                                Picker("", selection: Binding(
                                    get: { item.groupId },
                                    set: { state.assign(itemId: item.id, to: $0) }
                                )) {
                                    Text("Ungrouped").tag(UUID?.none)
                                    ForEach(state.state.groups) { group in
                                        Text(group.title).tag(UUID?.some(group.id))
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 170)

                                Toggle("", isOn: Binding(
                                    get: { !item.isVisible },
                                    set: { shouldHide in state.setVisibility(itemId: item.id, visible: !shouldHide) }
                                ))
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .frame(width: 86)
                                .disabled(!item.canToggleSystemVisibility)
                            }
                        }
                    }
                    .frame(minHeight: 340)
                }
            }
        }
    }

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Groups").font(.title2.bold())
            infoCard(title: "Create Group") {
                HStack {
                    TextField("New group name", text: $newGroupName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 260)

                    Button("Add Group") {
                        state.addGroup(title: newGroupName.trimmingCharacters(in: .whitespacesAndNewlines), symbolName: "square.grid.2x2")
                        newGroupName = ""
                    }
                    .disabled(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Spacer()
                }
            }

            infoCard(title: "Existing Groups") {
                if state.state.groups.isEmpty {
                    Text("No groups yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(state.state.groups) { group in
                        Label(group.title, systemImage: group.symbolName)
                    }
                }
            }
        }
    }

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shortcuts").font(.title2.bold())
            infoCard(title: "Global Toggle Shortcut") {
                Picker("Global shortcut", selection: Binding(
                    get: { state.state.preferences.globalToggleShortcut },
                    set: { state.setGlobalToggleShortcut($0) }
                )) {
                    ForEach(shortcutOptions, id: \.self) { shortcut in
                        Text(shortcut).tag(shortcut)
                    }
                }
                .frame(width: 220)

                Text("Default is ⌥⌘B. Changes apply immediately.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings").font(.title2.bold())
            infoCard(title: "Behavior") {
                Toggle("Hide newly discovered items by default", isOn: Binding(
                    get: { state.state.preferences.hideNewItemsByDefault },
                    set: { state.setHideNewItemsByDefault($0) }
                ))

                Toggle("Start at login", isOn: Binding(
                    get: { state.state.preferences.launchAtLogin },
                    set: { state.setLaunchAtLogin($0) }
                ))
            }

            infoCard(title: "Accessibility") {
                HStack {
                    Text(state.accessibilityEnabled() ? "Granted" : "Not granted")
                        .foregroundStyle(state.accessibilityEnabled() ? .green : .orange)
                    Spacer()
                    Button("Open Permission Prompt") {
                        state.requestAccessibilityPermission()
                    }
                }
                Text("Required to index real menu bar items and toggle system visibility where supported.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            infoCard(title: "Stein Icon") {
                Picker("Stein icon", selection: Binding(
                    get: { state.state.preferences.menuBarSymbolName },
                    set: { state.setMenuBarSymbol($0) }
                )) {
                    ForEach(iconOptions, id: \.0) { icon, label in
                        Label(label, systemImage: icon).tag(icon)
                    }
                }
                .frame(width: 280)
            }
        }
    }

    private func infoCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    private func stat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.footnote).foregroundStyle(.secondary)
            Text(value).font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
