import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppStateStore()
    private var statusController: StatusItemController?
    private var preferencesWindowController: PreferencesWindowController?
    private var hotKeyManager: GlobalHotKeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusController = StatusItemController(state: state) { [weak self] in
            self?.showPreferences()
        }

        hotKeyManager = GlobalHotKeyManager { [weak self] in
            self?.statusController?.triggerGlobalToggle()
        }
        hotKeyManager?.updateShortcut(state.state.preferences.globalToggleShortcut)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onStateChanged),
            name: .steinStateDidChange,
            object: nil
        )
    }

    @objc private func onStateChanged() {
        statusController?.refresh()
        hotKeyManager?.updateShortcut(state.state.preferences.globalToggleShortcut)
    }

    private func showPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController(state: state)
        }
        preferencesWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
