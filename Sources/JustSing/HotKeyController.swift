import AppKit
import Carbon

private enum JustSingHotKeyID {
    static let toggleReduction: UInt32 = 1
}

private var hotKeyControllers: [UInt32: HotKeyController] = [:]
private var sharedEventHandler: EventHandlerRef?

private func hotKeyEventHandler(
    callRef: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, GetEventKind(event) == UInt32(kEventHotKeyPressed) else {
        return OSStatus(eventNotHandledErr)
    }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return OSStatus(eventNotHandledErr) }

    guard let controller = hotKeyControllers[hotKeyID.id] else {
        return OSStatus(eventNotHandledErr)
    }

    DispatchQueue.main.async {
        controller.handlePressed()
    }
    return noErr
}

final class HotKeyController {
    static let defaultKeyCode = UInt32(kVK_ANSI_M)
    static let defaultModifiers = UInt32(cmdKey | optionKey)
    static let displayString = "⌘⌥M"

    private var hotKeyRef: EventHotKeyRef?
    private let id: UInt32
    private let onToggle: () -> Void

    init(id: UInt32 = JustSingHotKeyID.toggleReduction, onToggle: @escaping () -> Void) {
        self.id = id
        self.onToggle = onToggle
    }

    deinit {
        unregister()
    }

    func registerDefaultHotKey() {
        unregister()

        if sharedEventHandler == nil {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            let installStatus = InstallEventHandler(
                GetEventDispatcherTarget(),
                hotKeyEventHandler,
                1,
                &eventType,
                nil,
                &sharedEventHandler
            )
            guard installStatus == noErr else {
                AppLogger.shared.error("Failed to install hotkey handler: \(installStatus)")
                return
            }
        }

        hotKeyControllers[id] = self

        let hotKeyID = EventHotKeyID(signature: fourCharCode("JSTG"), id: id)
        let registerStatus = RegisterEventHotKey(
            Self.defaultKeyCode,
            Self.defaultModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        if registerStatus != noErr {
            hotKeyControllers.removeValue(forKey: id)
            AppLogger.shared.error("Failed to register \(Self.displayString) hotkey: \(registerStatus)")
        } else {
            AppLogger.shared.info("Registered global hotkey \(Self.displayString)")
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        hotKeyControllers.removeValue(forKey: id)
    }

    fileprivate func handlePressed() {
        onToggle()
    }
}

private func fourCharCode(_ string: String) -> OSType {
    string.utf8.reduce(0) { result, character in
        (result << 8) + OSType(character)
    }
}
