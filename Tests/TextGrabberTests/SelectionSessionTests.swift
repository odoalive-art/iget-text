import AppKit
import Carbon
import XCTest
@testable import TextGrabberKit

final class SelectionSessionTests: XCTestCase {
    func testShortcutDisplayStringIncludesModifiersAndKey() {
        let shortcut = KeyboardShortcut(
            keyCode: UInt32(kVK_ANSI_T),
            carbonModifiers: UInt32(cmdKey | optionKey | controlKey)
        )

        XCTAssertEqual(shortcut.displayString, "^⌥⌘T")
    }

    func testModifierOnlyShortcutDisplaysOnlyModifiers() {
        let shortcut = KeyboardShortcut(
            keyCode: nil,
            carbonModifiers: UInt32(controlKey | optionKey)
        )

        XCTAssertEqual(shortcut.displayString, "^⌥")
        XCTAssertTrue(shortcut.modifierOnly)
    }

    func testKeyboardShortcutFromKeyEventBuildsShortcutWithKeyCodeAndModifiers() throws {
        let event = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [.command, .option],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "r",
                charactersIgnoringModifiers: "r",
                isARepeat: false,
                keyCode: UInt16(kVK_ANSI_R)
            )
        )

        let shortcut = try XCTUnwrap(KeyboardShortcut.from(event: event))

        XCTAssertEqual(shortcut.keyCode, UInt32(kVK_ANSI_R))
        XCTAssertEqual(shortcut.carbonModifiers, UInt32(cmdKey | optionKey))
        XCTAssertFalse(shortcut.modifierOnly)
    }

    func testKeyboardShortcutFromModifierEventCreatesModifierOnlyShortcut() throws {
        let event = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .flagsChanged,
                location: .zero,
                modifierFlags: [.control, .option],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "",
                charactersIgnoringModifiers: "",
                isARepeat: false,
                keyCode: UInt16(kVK_Option)
            )
        )

        let shortcut = try XCTUnwrap(KeyboardShortcut.from(event: event))

        XCTAssertNil(shortcut.keyCode)
        XCTAssertEqual(shortcut.carbonModifiers, UInt32(controlKey | optionKey))
        XCTAssertTrue(shortcut.modifierOnly)
    }

    func testKeyboardShortcutFromModifierEventRejectsSingleModifierShortcut() throws {
        let event = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .flagsChanged,
                location: .zero,
                modifierFlags: [.control],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "",
                charactersIgnoringModifiers: "",
                isARepeat: false,
                keyCode: UInt16(kVK_Control)
            )
        )

        XCTAssertNil(KeyboardShortcut.from(event: event))
    }
}
