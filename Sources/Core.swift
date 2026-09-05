import AppKit
import Carbon

struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var keyLabel: String
    var label: String {
        [(UInt32(controlKey), "⌃"), (UInt32(optionKey), "⌥"),
         (UInt32(shiftKey), "⇧"), (UInt32(cmdKey), "⌘")]
            .filter { modifiers & $0.0 != 0 }.map { $0.1 }.joined() + keyLabel
    }
    func matches(_ other: Shortcut) -> Bool {
        keyCode == other.keyCode && modifiers == other.modifiers
    }
    static func from(_ event: NSEvent) -> Shortcut? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // A primary modifier prevents ordinary typing from becoming a global shortcut.
        guard !flags.intersection([.control, .option, .command]).isEmpty else { return nil }
        var modifiers: UInt32 = 0
        for (flag, carbon) in [(NSEvent.ModifierFlags.control, controlKey), (.option, optionKey),
                               (.shift, shiftKey), (.command, cmdKey)] where flags.contains(flag) {
            modifiers |= UInt32(carbon)
        }
        let special: [UInt16: String] = [36: "↩", 48: "⇥", 49: "Leertaste", 51: "⌫", 53: "Esc",
            123: "←", 124: "→", 125: "↓", 126: "↑", 115: "Home", 119: "End", 116: "Page Up", 121: "Page Down",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
            101: "F9", 109: "F10", 103: "F11", 111: "F12"]
        // Remove Option for readable labels: Option+1 should display 1, not its alternate glyph.
        let label = special[event.keyCode] ?? event.characters(byApplyingModifiers: [])?.uppercased() ?? "Taste \(event.keyCode)"
        return Shortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers, keyLabel: label)
    }
}

struct Binding: Codable, Identifiable {
    var id: Int
    var displayUUID: String?
    var displayName: String?
    var shortcut: Shortcut
    static func defaults() -> [Binding] {
        [UInt32(kVK_ANSI_1), UInt32(kVK_ANSI_2), UInt32(kVK_ANSI_3)].enumerated().map {
            Binding(id: $0.offset, shortcut: Shortcut(keyCode: $0.element,
                modifiers: UInt32(controlKey | optionKey), keyLabel: String($0.offset + 1)))
        }
    }
}

struct Display: Identifiable {
    let id: String
    let number: CGDirectDisplayID
    let name: String
    let bounds: CGRect
    var center: CGPoint { CGPoint(x: bounds.midX, y: bounds.midY) }

    static func connected() -> [Display] {
        NSScreen.screens.compactMap { screen -> Display? in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else { return nil }
            return Display(id: CFUUIDCreateString(nil, uuid) as String, number: number.uint32Value,
                           name: screen.localizedName, bounds: CGDisplayBounds(number.uint32Value))
        }.sorted {
            if $0.bounds.minX != $1.bounds.minX { return $0.bounds.minX < $1.bounds.minX }
            if $0.bounds.minY != $1.bounds.minY { return $0.bounds.minY < $1.bounds.minY }
            return $0.id < $1.id
        }
    }
}

final class HotKeyManager {
    private var references: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    var onPress: ((Int) -> Void)?
    private(set) var installStatus: OSStatus = noErr

    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        installStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard result == noErr, identifier.signature == 0x4D535052 else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(context).takeUnretainedValue()
            manager.onPress?(Int(identifier.id))
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    func unregister() {
        for reference in references { UnregisterEventHotKey(reference) }
        references.removeAll()
    }

    func register(_ bindings: [Binding]) -> [Int: String] {
        unregister()
        var errors: [Int: String] = [:]
        for binding in bindings {
            guard installStatus == noErr else {
                errors[binding.id] = "Hotkey-Dienst nicht verfügbar (\(installStatus))."; continue
            }
            var reference: EventHotKeyRef?
            let status = RegisterEventHotKey(binding.shortcut.keyCode, binding.shortcut.modifiers,
                EventHotKeyID(signature: 0x4D535052, id: UInt32(binding.id)), GetApplicationEventTarget(), 0, &reference)
            if status == noErr, let reference { references.append(reference) }
            else { errors[binding.id] = "Shortcut belegt oder nicht verfügbar (\(status)). Bitte ändern." }
        }
        return errors
    }
    deinit { unregister(); if let handler { RemoveEventHandler(handler) } }
}
