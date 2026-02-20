import XCTest
@testable import SteinApp

final class ModelDefaultsTests: XCTestCase {
    func testDefaultPreferencesAreStable() {
        let prefs = AppPreferences.default
        XCTAssertEqual(prefs.menuBarSymbolName, "wineglass")
        XCTAssertEqual(prefs.globalToggleShortcut, "⌥⌘B")
        XCTAssertFalse(prefs.launchAtLogin)
    }

    func testInitialStateStartsEmpty() {
        let state = PersistedState.initial
        XCTAssertTrue(state.groups.isEmpty)
        XCTAssertTrue(state.items.isEmpty)
    }

    func testManagedItemCodableRoundTrip() throws {
        let item = ManagedItem(
            title: "Wi-Fi",
            isVisible: true,
            groupId: UUID(),
            owningPID: 123,
            axIdentifier: "AXMenuExtra::wifi",
            canToggleSystemVisibility: true
        )

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(ManagedItem.self, from: data)
        XCTAssertEqual(decoded, item)
    }
}
