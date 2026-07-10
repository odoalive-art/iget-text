import AppKit
import Carbon
import XCTest
@testable import TextGrabberKit

@MainActor
final class AppSettingsTests: XCTestCase {
    func testUsesDefaultHotkeyWhenNoStoredValueExists() {
        let defaults = makeDefaults()

        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.hotkey, .defaultValue)
    }

    func testMigratesLegacyDefaultHotkeyToNewDefault() throws {
        let defaults = makeDefaults()
        let data = try JSONEncoder().encode(KeyboardShortcut.legacyDefaultValue)
        defaults.set(data, forKey: "app.hotkey")

        let settings = AppSettings(defaults: defaults)
        let storedShortcut = try XCTUnwrap(loadStoredShortcut(from: defaults))

        XCTAssertEqual(settings.hotkey, .defaultValue)
        XCTAssertEqual(storedShortcut, .defaultValue)
    }

    func testPersistsUpdatedHotkeyToUserDefaults() throws {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        let newShortcut = KeyboardShortcut(
            keyCode: UInt32(kVK_ANSI_R),
            carbonModifiers: UInt32(cmdKey | shiftKey)
        )

        settings.hotkey = newShortcut

        XCTAssertEqual(try XCTUnwrap(loadStoredShortcut(from: defaults)), newShortcut)
    }

    func testResetHotkeyRestoresDefaultValue() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.hotkey = KeyboardShortcut(
            keyCode: UInt32(kVK_ANSI_S),
            carbonModifiers: UInt32(optionKey | shiftKey)
        )

        settings.resetHotkey()

        XCTAssertEqual(settings.hotkey, .defaultValue)
    }

    func testUsesDefaultModesWhenNoStoredValueExists() {
        let defaults = makeDefaults()

        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.activationMode, .keyboardShortcut)
        XCTAssertEqual(settings.doubleTapModifier, .command)
        XCTAssertEqual(settings.resultPanelPlacement, .statusItem)
        XCTAssertEqual(settings.translationProvider, .automatic)
    }

    func testPersistsActivationModeAndResultPanelPlacement() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.activationMode = .functionKey
        settings.resultPanelPlacement = .followMouse
        settings.translationProvider = .systemOnly

        XCTAssertEqual(defaults.string(forKey: "app.activationMode"), CaptureActivationMode.functionKey.rawValue)
        XCTAssertEqual(defaults.string(forKey: "app.resultPanelPlacement"), ResultPanelPlacementMode.followMouse.rawValue)
        XCTAssertEqual(defaults.string(forKey: "app.translationProvider"), TranslationProviderMode.systemOnly.rawValue)
    }

    func testPersistsAndRestoresDoubleTapModifier() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.activationMode = .doubleModifierTap
        settings.doubleTapModifier = .shift

        XCTAssertEqual(defaults.string(forKey: "app.activationMode"), CaptureActivationMode.doubleModifierTap.rawValue)
        XCTAssertEqual(defaults.string(forKey: "app.doubleTapModifier"), DoubleTapModifier.shift.rawValue)

        let restored = AppSettings(defaults: defaults)
        XCTAssertEqual(restored.activationMode, .doubleModifierTap)
        XCTAssertEqual(restored.doubleTapModifier, .shift)
    }

    func testDoubleTapModifierMapsToModifierFlag() {
        XCTAssertEqual(DoubleTapModifier.command.modifierFlag, .command)
        XCTAssertEqual(DoubleTapModifier.option.modifierFlag, .option)
        XCTAssertEqual(DoubleTapModifier.control.modifierFlag, .control)
        XCTAssertEqual(DoubleTapModifier.shift.modifierFlag, .shift)
    }

    private func makeDefaults(file: StaticString = #filePath, line: UInt = #line) -> UserDefaults {
        let suiteName = "TextGrabberTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated defaults suite", file: file, line: line)
            return .standard
        }

        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func loadStoredShortcut(from defaults: UserDefaults) -> KeyboardShortcut? {
        guard let data = defaults.data(forKey: "app.hotkey") else {
            return nil
        }

        return try? JSONDecoder().decode(KeyboardShortcut.self, from: data)
    }
}
