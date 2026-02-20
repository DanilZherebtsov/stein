import AppKit
import ServiceManagement

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
        applyLaunchAtLoginPreference()

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
        applyLaunchAtLoginPreference()
    }

    private func applyLaunchAtLoginPreference() {
        guard #available(macOS 13.0, *) else { return }
        do {
            if state.state.preferences.launchAtLogin {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("Stein: failed to update launch-at-login setting: \(error.localizedDescription)")
        }
    }

    private func showPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController(state: state)
        }
        preferencesWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
