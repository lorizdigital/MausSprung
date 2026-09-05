# MausSprung

**Jump your mouse pointer to the center of a display with a keyboard shortcut.** A small, native macOS menu bar app with three configurable shortcuts. No dependencies, accounts, or network access. The interface is currently in German.

Kleine native macOS-Menüleisten-App: drei frei belegbare globale Tastenkombinationen bewegen den Mauszeiger in die Mitte eines zugewiesenen Bildschirms. Swift, AppKit und SwiftUI; keine externen Pakete, keine Netzwerkzugriffe.

## Installation

Die fertige Apple-Silicon-App gibt es unter [Releases](https://github.com/lorizdigital/MausSprung/releases/latest). ZIP entpacken, `MausSprung.app` nach „Programme“ ziehen und öffnen. Voraussetzung: macOS 13 oder neuer. Für Intel-Macs kann die App aus dem Quellcode gebaut werden; Intel wurde noch nicht getestet.

Die App ist lokal ad-hoc signiert, aber nicht mit einem Apple-Developer-Zertifikat signiert oder notarisiert. macOS kann deshalb beim Öffnen der heruntergeladenen App eine Sicherheitsmeldung anzeigen. Alternativ aus dem Quellcode bauen.

## Benutzen

1. `MausSprung.app` öffnen. Optional vorher im Finder nach „Programme“ ziehen.
2. Die drei Ziele sind beim ersten Start nach Bildschirmposition von links nach rechts zugewiesen; bei gleicher horizontaler Position von oben nach unten.
3. Standard: **Control + Option + 1 / 2 / 3**.
4. Bildschirm über das Auswahlfeld ändern. Die Nummer im Auswahlfeld bezieht sich auf diese App, nicht auf eine macOS-eigene Bildschirmnummer. Bei gleichnamigen Monitoren hilft der Pfeilknopf rechts zum Testen der Zuordnung.
5. Zum Ändern auf den Shortcut klicken und die gewünschte Kombination drücken. Mindestens Control, Option oder Command ist erforderlich. Escape bricht ab. Funktionstasten hängen gegebenenfalls von der Fn-Einstellung des Mac ab. Die gespeicherte Taste ist eine physische Tastenposition; nach Wechsel des Tastaturlayouts gegebenenfalls neu aufnehmen.
6. Das Fenster kann geschlossen werden; die App läuft in der Menüleiste weiter. Über das Mauszeiger-Symbol lassen sich Einstellungen öffnen und die App beenden.

## Verhalten

- Speichert Shortcuts und Bildschirm-UUIDs lokal in macOS UserDefaults unter `de.lorizdigital.maussprung`.
- Ein abgezogener Bildschirm behält seinen Platz. Der zugehörige Shortcut springt nicht auf einen anderen Bildschirm; bei Aufruf ertönt ein Hinweis. Wiederanschließen wird automatisch erkannt.
- Neue Monitore werden nur noch unzugewiesenen Zielen automatisch zugeordnet. Bei geänderter Hardwarekennung, etwa durch einen anderen Adapter, kann eine erneute Auswahl nötig sein.
- Spiegelbildschirme stellen keine unabhängigen Desktopziele dar.
- Belegte Shortcuts werden angezeigt. Eine erfolglose neue Belegung setzt den bisherigen Shortcut wieder ein. Reservierte macOS- oder App-Kombinationen können trotzdem Vorrang haben; in diesem Fall eine andere Kombination wählen.
- Während einer Shortcut-Aufnahme sind die drei globalen Shortcuts pausiert; Abbrechen, Fenster schließen oder App-Wechsel aktiviert sie wieder.
- „Standard-Shortcuts“ setzt nur die Tastenkombinationen zurück; Bildschirmzuordnungen bleiben erhalten.
- Optionaler Autostart: Die App über die macOS-Systemeinstellungen zu den Anmeldeobjekten hinzufügen. Autostart wird von der App nicht automatisch eingerichtet.

## Bauen

Benötigt macOS 13 oder neuer und Xcode bzw. die Apple Command Line Tools mit Swift.

```sh
git clone https://github.com/lorizdigital/MausSprung.git
cd MausSprung
bash build.sh
```

Erstellt `../MausSprung.app` für die Architektur des ausführenden Mac. Zusätzlich entsteht `../MausSprung.zip`. Das Release-Paket wird für Apple Silicon gebaut und lokal ad-hoc signiert; es ist nicht notarisiert.

## Prüfung

```sh
../MausSprung.app/Contents/MacOS/MausSprung --self-test
../MausSprung.app/Contents/MacOS/MausSprung --diagnostics
# Vorher die laufende MausSprung-App beenden, damit ihre Shortcuts nicht als belegt gelten.
../MausSprung.app/Contents/MacOS/MausSprung --smoke-test
```

Der Smoke-Test benötigt Zugriff auf die angemeldete macOS-Grafiksitzung. Er registriert die Standard-Shortcuts, prüft absichtliche Doppelregistrierungen und bewegt den Zeiger auf alle verbundenen Bildschirmmitten. Anschließend stellt er die ursprüngliche Position wieder her. Während des Tests die Maus nicht selbst bewegen.

Am 05.09.2026 geprüft:

- Kompilierung mit Apple Swift 6.3.3 im Swift-5-Sprachmodus.
- Acht Selbsttests: Koordinaten für Hauptmonitor, links, oben und Hochformat; Standardbelegung; JSON-Speicherung; Shortcut-Vergleich.
- Live: Registrierung aller drei Shortcuts und Konflikterkennung erfolgreich. Cursorposition nach Bewegung auf allen drei angeschlossenen Displays ausgelesen und mit der jeweiligen Mitte verglichen.
- Oberfläche: App geöffnet und visuell geprüft, Sprung per Testknopf ausgeführt, Ctrl+Option+4 aufgenommen, doppelte Belegung abgefangen, Aufnahme abgebrochen und Standards wiederhergestellt.
- Die automatische UI-Prüfung deckt die Shortcut-Aufnahme ab, nicht die globale Auslösung durch physische Tastendrücke. Letztere muss bei manuellen Tests aus einer anderen App geprüft werden.
- Abziehen/Wiederanschließen und ein kompletter Neustart wurden nicht live getestet.

## Aufbau

- `Sources/Core.swift`: Datenmodelle, Bildschirmerkennung, Shortcut-Umwandlung und globale Carbon-Hotkeys.
- `Sources/AppModel.swift`: Zuordnung, Persistenz, Aufnahme und Cursorbewegung.
- `Sources/SettingsView.swift`: Einstellungsoberfläche.
- `Sources/main.swift`: Menüleiste, Fenster und Programmeinstieg.
- `Sources/Tests.swift`: Selbsttests und Live-Smoke-Test.

Für Cursorbewegungen werden durchgehend globale Core-Graphics-Koordinaten verwendet. Dadurch wird die entgegengesetzte Y-Achse von AppKit nicht versehentlich eingemischt. Apple-Referenzen: [CGDisplayBounds](https://developer.apple.com/documentation/coregraphics/cgdisplaybounds(_:)), [CGWarpMouseCursorPosition](https://developer.apple.com/documentation/coregraphics/cgwarpmousecursorposition(_:)).

## Mitwirken

Fehlerberichte und Pull Requests sind willkommen. Bitte bei Fehlern macOS-Version, Mac-Architektur, Monitoranordnung und Schritte zum Reproduzieren angeben. Vor Pull Requests `bash build.sh` und `--self-test` ausführen; Änderungen an Hotkeys zusätzlich manuell aus einer anderen App prüfen.

## Lizenz

[MIT](LICENSE) · Copyright (c) 2026 Loriz Digital
