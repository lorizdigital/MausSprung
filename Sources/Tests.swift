import AppKit
import Carbon

struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

func check(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    guard try condition() else { throw TestFailure(description: message) }
    print("PASS: \(message)")
}

private final class MockLaunchAtLoginService: LaunchAtLoginServicing {
    var status: LaunchAtLoginStatus
    var registerError: Error?
    private(set) var registerCalls = 0
    private(set) var unregisterCalls = 0
    private(set) var settingsCalls = 0

    init(status: LaunchAtLoginStatus) { self.status = status }

    func register() throws {
        registerCalls += 1
        if let registerError { throw registerError }
        status = .enabled
    }

    func unregister() throws {
        unregisterCalls += 1
        status = .disabled
    }

    func openSystemSettings() { settingsCalls += 1 }
}

func runSelfTests() throws {
    let layouts: [(CGRect, CGPoint)] = [
        (CGRect(x: 0, y: 0, width: 1920, height: 1080), CGPoint(x: 960, y: 540)),
        (CGRect(x: -2560, y: 0, width: 2560, height: 1440), CGPoint(x: -1280, y: 720)),
        (CGRect(x: 0, y: -1440, width: 2560, height: 1440), CGPoint(x: 1280, y: -720)),
        (CGRect(x: 1920, y: 300, width: 1080, height: 1920), CGPoint(x: 2460, y: 1260))]
    for (rect, expected) in layouts {
        try check(Display(id: "test", number: 1, name: "test", bounds: rect).center == expected, "Bildschirmmitte \(rect)")
    }
    let defaults = Binding.defaults()
    try check(defaults.map(\.shortcut.label) == ["⌃⌥1", "⌃⌥2", "⌃⌥3"], "Standardbelegung")
    var original = defaults
    original[0].displayUUID = "stable-display-uuid"
    let decoded = try JSONDecoder().decode([Binding].self, from: JSONEncoder().encode(original))
    try check(decoded[0].displayUUID == original[0].displayUUID && decoded[0].shortcut == original[0].shortcut, "Speicherformat mit stabiler Bildschirmkennung")
    var renamed = defaults[0].shortcut; renamed.keyLabel = "anderer Name"
    try check(defaults[0].shortcut.matches(renamed), "Duplikaterkennung unabhängig vom Anzeigenamen")
    try check(!defaults[0].shortcut.matches(defaults[1].shortcut), "Unterschiedliche Tasten")
    func accepts(_ values: [Binding]) throws -> Bool {
        Binding.decodeValidated(try JSONEncoder().encode(values)) != nil
    }
    try check(try accepts(defaults), "Gültige Einstellungen akzeptieren")
    for mask in [UInt32(0), UInt32(shiftKey), UInt32(controlKey) | 0x80000000] {
        var invalid = defaults; invalid[0].shortcut.modifiers = mask
        try check(try !accepts(invalid), "Ungültige Modifier ablehnen: \(mask)")
    }
    var duplicate = defaults; duplicate[1].shortcut = duplicate[0].shortcut
    try check(try !accepts(duplicate), "Doppelte gespeicherte Shortcuts ablehnen")
    var badID = defaults; badID[0].id = 10
    try check(try !accepts(badID), "Ungültige gespeicherte ID ablehnen")
    try check(Binding.decodeValidated(Data(repeating: 0, count: 65_537)) == nil, "Überlange Einstellungen ablehnen")
    let originalPoint = CGPoint(x: 20, y: 30)
    var restored: CGPoint?
    do {
        try withRestoredCursor(originalPoint, move: { restored = $0; return .success }) {
            throw TestFailure(description: "simulated failure")
        }
        throw TestFailure(description: "Fehler wurde verschluckt")
    } catch let error as TestFailure {
        try check(error.description == "simulated failure" && restored == originalPoint,
                  "Mausposition bei Fehler wiederherstellen und Fehler weitergeben")
    }
    restored = nil
    try withRestoredCursor(originalPoint, move: { restored = $0; return .success }) {}
    try check(restored == originalPoint, "Mausposition bei Erfolg wiederherstellen")
    do {
        try withRestoredCursor(originalPoint, move: { _ in .failure }) {}
        throw TestFailure(description: "Wiederherstellungsfehler verschluckt")
    } catch let error as TestFailure {
        try check(error.description.contains("Wiederherstellung fehlgeschlagen"), "Wiederherstellungsfehler melden")
    }
    let loginService = MockLaunchAtLoginService(status: .disabled)
    let loginController = LaunchAtLoginController(service: loginService)
    try check(!loginController.isEnabled, "Autostart-Status ausgeschaltet lesen")
    loginController.setEnabled(true)
    try check(loginController.isEnabled && loginService.registerCalls == 1,
              "Autostart über macOS registrieren")
    loginController.setEnabled(false)
    try check(!loginController.isEnabled && loginService.unregisterCalls == 1,
              "Autostart über macOS abmelden")
    loginService.status = .requiresApproval
    loginController.refresh()
    try check(loginController.isEnabled && loginController.requiresApproval,
              "Ausstehende macOS-Freigabe anzeigen")
    loginController.openSystemSettings()
    try check(loginService.settingsCalls == 1, "Anmeldeobjekte-Einstellungen öffnen")
    loginService.status = .unavailable
    loginService.registerError = nil
    loginController.refresh()
    loginController.setEnabled(true)
    try check(loginController.isEnabled && loginService.registerCalls == 2,
              "Registrierung auch ohne vorherigen Status versuchen")
    loginController.setEnabled(false)
    loginService.status = .disabled
    loginService.registerError = NSError(domain: "MausSprungTests", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "simulated registration failure"])
    loginController.setEnabled(true)
    try check(!loginController.isEnabled && loginController.message?.contains("simulated registration failure") == true,
              "Fehler bei der Autostart-Registrierung melden")
    print("Alle Selbsttests bestanden.")
}

func runSmokeTest() throws {
    _ = NSApplication.shared
    let manager = HotKeyManager()
    let errors = manager.register(Binding.defaults())
    try check(errors.isEmpty, "Globale Standard-Shortcuts registrieren: \(errors)")
    let conflict = HotKeyManager()
    try check(conflict.register(Binding.defaults()).count == 3, "Konflikte mit bereits registrierten Shortcuts erkennen")
    conflict.unregister(); manager.unregister()
    let displays = Display.connected()
    try check(!displays.isEmpty, "Verbundene Bildschirme vorhanden: \(displays.count)")
    guard let original = CGEvent(source: nil)?.location else { try check(false, "Cursorposition lesen"); return }
    try withRestoredCursor(original, move: CGWarpMouseCursorPosition) {
        for display in displays {
            try check(CGWarpMouseCursorPosition(display.center) == .success, "Cursor bewegen: \(display.name)")
            guard let actual = CGEvent(source: nil)?.location else { try check(false, "Cursorposition lesen"); return }
            try check(abs(actual.x - display.center.x) <= 1 && abs(actual.y - display.center.y) <= 1,
                  "Cursor ist in Bildschirmmitte: \(display.name), \(actual)")
        }
    }
    print("Live-Smoke-Test bestanden; ursprüngliche Mausposition wiederhergestellt.")
}

/// Unwind normally on test failure; exit() inside the operation would bypass cleanup.
/// Injecting the move operation lets self-tests cover failures without moving the real cursor.
func withRestoredCursor(_ original: CGPoint, move: (CGPoint) -> CGError,
                        operation: () throws -> Void) throws {
    var operationError: Error?
    do { try operation() } catch { operationError = error }
    let restored = move(original)
    guard restored == .success else {
        throw TestFailure(description: "Wiederherstellung fehlgeschlagen (\(restored.rawValue)). Ursprünglicher Fehler: \(operationError.map(String.init(describing:)) ?? "keiner")")
    }
    if let operationError { throw operationError }
}
