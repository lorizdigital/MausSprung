import AppKit
import Carbon

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fputs("FAIL: \(message)\n", stderr); exit(1) }
    print("PASS: \(message)")
}

func runSelfTests() {
    let layouts: [(CGRect, CGPoint)] = [
        (CGRect(x: 0, y: 0, width: 1920, height: 1080), CGPoint(x: 960, y: 540)),
        (CGRect(x: -2560, y: 0, width: 2560, height: 1440), CGPoint(x: -1280, y: 720)),
        (CGRect(x: 0, y: -1440, width: 2560, height: 1440), CGPoint(x: 1280, y: -720)),
        (CGRect(x: 1920, y: 300, width: 1080, height: 1920), CGPoint(x: 2460, y: 1260))]
    for (rect, expected) in layouts {
        check(Display(id: "test", number: 1, name: "test", bounds: rect).center == expected, "Bildschirmmitte \(rect)")
    }
    let defaults = Binding.defaults()
    check(defaults.map(\.shortcut.label) == ["⌃⌥1", "⌃⌥2", "⌃⌥3"], "Standardbelegung")
    var original = defaults
    original[0].displayUUID = "stable-display-uuid"
    let decoded = try! JSONDecoder().decode([Binding].self, from: JSONEncoder().encode(original))
    check(decoded[0].displayUUID == original[0].displayUUID && decoded[0].shortcut == original[0].shortcut, "Speicherformat mit stabiler Bildschirmkennung")
    var renamed = defaults[0].shortcut; renamed.keyLabel = "anderer Name"
    check(defaults[0].shortcut.matches(renamed), "Duplikaterkennung unabhängig vom Anzeigenamen")
    check(!defaults[0].shortcut.matches(defaults[1].shortcut), "Unterschiedliche Tasten")
    print("Alle Selbsttests bestanden.")
}

func runSmokeTest() {
    _ = NSApplication.shared
    let manager = HotKeyManager()
    let errors = manager.register(Binding.defaults())
    check(errors.isEmpty, "Globale Standard-Shortcuts registrieren: \(errors)")
    let conflict = HotKeyManager()
    check(conflict.register(Binding.defaults()).count == 3, "Konflikte mit bereits registrierten Shortcuts erkennen")
    conflict.unregister(); manager.unregister()
    let displays = Display.connected()
    check(!displays.isEmpty, "Verbundene Bildschirme vorhanden: \(displays.count)")
    guard let original = CGEvent(source: nil)?.location else { check(false, "Cursorposition lesen"); return }
    defer { CGWarpMouseCursorPosition(original) }
    for display in displays {
        check(CGWarpMouseCursorPosition(display.center) == .success, "Cursor bewegen: \(display.name)")
        guard let actual = CGEvent(source: nil)?.location else { check(false, "Cursorposition lesen"); return }
        check(abs(actual.x - display.center.x) <= 1 && abs(actual.y - display.center.y) <= 1,
              "Cursor ist in Bildschirmmitte: \(display.name), \(actual)")
    }
    print("Live-Smoke-Test bestanden; ursprüngliche Mausposition wird wiederhergestellt.")
}
