import AppKit
import Carbon.HIToolbox

// MARK: - GlobalHotKey
//
// A tiny wrapper around Carbon's RegisterEventHotKey — the sandbox-safe way to
// register a system-wide hotkey. It needs NO Accessibility / Input-Monitoring
// permission (unlike a global NSEvent keyDown monitor), so it doesn't prompt the
// user — which keeps Seedling feeling "not there."
//
// One instance manages one hotkey. The Carbon callback is a non-capturing C
// function pointer; we pass `self` as the handler's refcon and recover it inside.
//
final class GlobalHotKey {

    /// ⌥⌘S — the default summon combo.
    static let defaultKeyCode = UInt32(kVK_ANSI_S)
    static let defaultModifiers = UInt32(cmdKey | optionKey)

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var handler: (() -> Void)?

    /// Register the hotkey. Replaces any previous registration. The handler is
    /// always invoked on the main thread.
    func register(keyCode: UInt32 = defaultKeyCode,
                  modifiers: UInt32 = defaultModifiers,
                  handler: @escaping () -> Void) {
        unregister()
        self.handler = handler

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let userData else { return noErr }
                let me = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { me.handler?() }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )

        // 'SEED' as a FourCharCode signature.
        let hotKeyID = EventHotKeyID(signature: OSType(0x5345_4544), id: 1)
        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        handler = nil
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
    }
}
