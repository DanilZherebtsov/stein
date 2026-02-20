import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    init(state: AppStateStore) {
        let view = PreferencesView(state: state)
        let hosting = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: hosting)
        window.title = "Stein Preferences"
        window.setContentSize(NSSize(width: 700, height: 500))
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct PreferencesView: View {
    @State private var refresh: Bool = false
    let state: AppStateStore

    private let iconOptions = ["wineglass", "square.stack.3d.up", "line.3.horizontal.decrease.circle", "tray.full"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Stein v1")
                .font(.title2).bold()

            Toggle("Hide newly discovered items by default", isOn: Binding(
                get: { state.state.preferences.hideNewItemsByDefault },
                set: { state.setHideNewItemsByDefault($0); refresh.toggle() }
            ))

            Picker("Stein icon", selection: Binding(
                get: { state.state.preferences.menuBarSymbolName },
                set: { state.setMenuBarSymbol($0); refresh.toggle() }
            )) {
                ForEach(iconOptions, id: \.self) { icon in
                    Text(icon).tag(icon)
                }
            }
            .pickerStyle(.segmented)

            Divider()

            Text("Managed Items")
                .font(.headline)

            List {
                ForEach(state.state.items) { item in
                    HStack {
                        Text(item.title)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { item.isVisible },
                            set: { state.setVisibility(itemId: item.id, visible: $0); refresh.toggle() }
                        ))
                        .labelsHidden()
                    }
                }
            }

            HStack {
                Button("Add Sample Item") {
                    state.addItem(title: "New Item \(Int.random(in: 1...999))")
                    refresh.toggle()
                }
                Spacer()
                Text("Global toggle shortcut placeholder: \(state.state.preferences.globalToggleShortcut)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
