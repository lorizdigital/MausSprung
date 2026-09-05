import SwiftUI

final class AppModel: ObservableObject {
    @Published var bindings: [Binding]
    @Published var displays: [Display] = []
    @Published var errors: [Int: String] = [:]
    @Published var recording: Int?
    @Published var notice = ""
    private let hotkeys = HotKeyManager()
    private var monitor: Any?
    private var observers: [NSObjectProtocol] = []
    private let storageKey = "bindings.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([Binding].self, from: data),
           saved.count == 3, saved.map(\.id) == [0, 1, 2],
           saved.allSatisfy({ $0.shortcut.keyCode <= 127 && $0.shortcut.modifiers != 0 }) {
            bindings = saved
        } else { bindings = Binding.defaults() }
        refreshDisplays()
        hotkeys.onPress = { [weak self] in self?.jump($0) }
        activateShortcuts()
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in self?.refreshDisplays() })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification,
            object: nil, queue: .main) { [weak self] _ in self?.cancelRecording() })
    }

    func refreshDisplays() {
        displays = Display.connected()
        // Only fill unassigned slots. Disconnected displays retain their saved identity.
        var used = Set(bindings.compactMap(\.displayUUID))
        for index in bindings.indices where bindings[index].displayUUID == nil {
            if let display = displays.first(where: { !used.contains($0.id) }) {
                bindings[index].displayUUID = display.id
                bindings[index].displayName = display.name
                used.insert(display.id)
            }
        }
        persist()
    }

    private func persist() {
        do { UserDefaults.standard.set(try JSONEncoder().encode(bindings), forKey: storageKey) }
        catch { notice = "Einstellungen konnten nicht gespeichert werden: \(error.localizedDescription)" }
    }

    func assign(_ id: Int, uuid: String) {
        guard let index = bindings.firstIndex(where: { $0.id == id }),
              let display = displays.first(where: { $0.id == uuid }) else { return }
        bindings[index].displayUUID = display.id
        bindings[index].displayName = display.name
        persist()
    }

    func jump(_ id: Int) {
        guard let binding = bindings.first(where: { $0.id == id }),
              let display = Display.connected().first(where: { $0.id == binding.displayUUID }) else {
            notice = "Bildschirm für Ziel \(id + 1) ist nicht verbunden."; NSSound.beep(); return
        }
        // Core Graphics coordinates avoid AppKit's inverted Y axis, also on vertical layouts.
        let result = CGWarpMouseCursorPosition(display.center)
        if result != .success { notice = "Mauszeiger konnte nicht bewegt werden (\(result.rawValue))."; NSSound.beep() }
        else { notice = "Mauszeiger auf \(display.name) zentriert." }
    }

    func activateShortcuts() { errors = hotkeys.register(bindings) }

    func startRecording(_ id: Int) {
        cancelRecording()
        recording = id
        notice = "Jetzt Tastenkombination drücken. Mindestens ⌃, ⌥ oder ⌘ verwenden. Esc bricht ab."
        hotkeys.unregister()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 { self.cancelRecording(); return nil }
            guard let shortcut = Shortcut.from(event) else {
                self.notice = "Bitte mindestens Control, Option oder Command gedrückt halten."; return nil
            }
            if self.bindings.contains(where: { $0.id != id && $0.shortcut.matches(shortcut) }) {
                self.notice = "Diese Tastenkombination wird bereits für ein anderes Ziel verwendet."; return nil
            }
            let previous = self.bindings
            self.bindings[id].shortcut = shortcut
            self.finishRecording()
            self.activateShortcuts()
            if let error = self.errors[id] {
                self.bindings = previous
                self.activateShortcuts()
                self.notice = "\(error) Bisheriger Shortcut bleibt gespeichert."
            } else { self.persist(); self.notice = "Shortcut \(shortcut.label) gespeichert." }
            return nil
        }
    }
    private func finishRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil; recording = nil
    }
    func cancelRecording() {
        guard recording != nil else { return }
        finishRecording(); activateShortcuts(); notice = "Aufnahme abgebrochen."
    }
    func resetShortcuts() {
        cancelRecording()
        let defaults = Binding.defaults()
        for index in bindings.indices { bindings[index].shortcut = defaults[index].shortcut }
        activateShortcuts(); persist(); notice = "Standard-Shortcuts wiederhergestellt."
    }
}
