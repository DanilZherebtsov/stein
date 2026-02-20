import Foundation
import Carbon

final class GlobalHotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let onToggle: () -> Void

    init(onToggle: @escaping () -> Void) {
        self.onToggle = onToggle
        installHandler()
    }

    deinit {
        unregister()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }

    func updateShortcut(_ shortcut: String) {
        unregister()
        guard let spec = HotKeySpec.from(shortcut: shortcut) else { return }

        var hotKeyID = EventHotKeyID(signature: OSType(0x53544E31), id: 1) // STN1
        RegisterEventHotKey(spec.keyCode, spec.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    private func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { _, eventRef, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()

            var hotKeyID = EventHotKeyID()
            let size = MemoryLayout<EventHotKeyID>.size
            GetEventParameter(eventRef,
                              EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID),
                              nil,
                              size,
                              nil,
                              &hotKeyID)

            if hotKeyID.id == 1 {
                manager.onToggle()
            }
            return noErr
        }, 1, &spec, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), &handlerRef)
    }
}

private struct HotKeySpec {
    let keyCode: UInt32
    let modifiers: UInt32

    static func from(shortcut: String) -> HotKeySpec? {
        switch shortcut {
        case "⌥⌘B": return HotKeySpec(keyCode: UInt32(kVK_ANSI_B), modifiers: UInt32(optionKey | cmdKey))
        case "⌥⌘S": return HotKeySpec(keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(optionKey | cmdKey))
        case "⌥⌘H": return HotKeySpec(keyCode: UInt32(kVK_ANSI_H), modifiers: UInt32(optionKey | cmdKey))
        case "⌃⌥⌘B": return HotKeySpec(keyCode: UInt32(kVK_ANSI_B), modifiers: UInt32(controlKey | optionKey | cmdKey))
        case "Disabled": return nil
        default: return HotKeySpec(keyCode: UInt32(kVK_ANSI_B), modifiers: UInt32(optionKey | cmdKey))
        }
    }
}
