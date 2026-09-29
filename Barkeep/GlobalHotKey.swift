import Carbon.HIToolbox

struct HotKeyCombo {
    let keyCode: Int
    let modifiers: Int
    let label: String

    static let toggle = HotKeyCombo(keyCode: kVK_ANSI_B, modifiers: controlKey | optionKey | cmdKey, label: "⌃⌥⌘B")
}

/// Carbon hot keys work without Accessibility permission, unlike global key monitors.
@MainActor
final class GlobalHotKey {
    private static let signature: OSType = 0x424B_4550 // "BKEP"

    let combo: HotKeyCombo
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: @MainActor () -> Void

    init?(_ combo: HotKeyCombo, action: @escaping @MainActor () -> Void) {
        self.combo = combo
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                MainActor.assumeIsolated { hotKey.action() }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
        guard installStatus == noErr else { return nil }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
        let registerStatus = RegisterEventHotKey(
            UInt32(combo.keyCode),
            UInt32(combo.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else {
            RemoveEventHandler(handlerRef)
            handlerRef = nil
            return nil
        }
    }

    /// The Carbon handler holds an unretained pointer to `self`, so it must go before `self` does.
    isolated deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
