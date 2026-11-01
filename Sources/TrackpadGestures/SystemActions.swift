import AppKit
import GestureCore

@MainActor
enum SystemActions {
    static func perform(_ gesture: Gesture) {
        switch gesture {
        case .threeFingerTap: middleClick()
        case .tipTapLeft: pressMediaKey(NX_KEYTYPE_SOUND_DOWN)
        case .tipTapRight: pressMediaKey(NX_KEYTYPE_SOUND_UP)
        case .tipTapMiddle: pressMediaKey(NX_KEYTYPE_MUTE)
        }
    }

    private static func middleClick() {
        let location = CGEvent(source: nil)?.location ?? .zero
        for type in [CGEventType.otherMouseDown, .otherMouseUp] {
            CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: location, mouseButton: .center)?
                .post(tap: .cghidEventTap)
        }
    }

    /// Sent like the keyboard's volume keys, so macOS shows its volume overlay and adjusts the current output.
    /// Subtype 8 is NX_SUBTYPE_AUX_CONTROL_BUTTONS; 0xA and 0xB in data1 mean key down and key up.
    private static func pressMediaKey(_ key: Int32) {
        for keyState in [0xA, 0xB] {
            NSEvent.otherEvent(
                with: .systemDefined, location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(keyState << 8)),
                timestamp: 0, windowNumber: 0, context: nil,
                subtype: 8, data1: Int(key) << 16 | keyState << 8, data2: -1
            )?.cgEvent?.post(tap: .cghidEventTap)
        }
    }
}
