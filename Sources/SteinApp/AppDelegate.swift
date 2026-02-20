import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppStateStore()
    private var statusController: StatusItemController?
    private var preferencesWindowController: PreferencesWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusController = StatusItemController(state: state) { [weak self] in
            self?.showPreferences()
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
