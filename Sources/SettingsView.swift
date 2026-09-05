import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(systemName: "cursorarrow.motionlines").font(.system(size: 34)).foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text("MausSprung").font(.largeTitle.bold())
                    Text("Drei Ziele. Ein Tastendruck.").foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(model.displays.count) verbunden").font(.caption).padding(8)
                    .background(.quaternary, in: Capsule())
            }
            Text("Wähle pro Ziel einen Bildschirm. Der Shortcut bewegt deinen Mauszeiger direkt in dessen Mitte.")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 12) {
                ForEach(model.bindings) { binding in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 14) {
                            Text("\(binding.id + 1)").font(.title2.bold()).foregroundStyle(.blue)
                                .frame(width: 36, height: 40)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Ziel \(binding.id + 1)").font(.headline)
                                Picker("Bildschirm", selection: SwiftUI.Binding(get: { binding.displayUUID ?? "" },
                                    set: { model.assign(binding.id, uuid: $0) })) {
                                    if !model.displays.contains(where: { $0.id == binding.displayUUID }) {
                                        Text(binding.displayUUID == nil ? "Kein Bildschirm zugewiesen" : "\(binding.displayName ?? "Bildschirm") – getrennt")
                                            .tag(binding.displayUUID ?? "")
                                    }
                                    ForEach(Array(model.displays.enumerated()), id: \.element.id) { index, display in
                                        Text("\(index + 1). \(display.name) · \(Int(display.bounds.width)) × \(Int(display.bounds.height))")
                                            .tag(display.id)
                                    }
                                }.labelsHidden().frame(maxWidth: .infinity)
                                    .accessibilityLabel("Bildschirm für Ziel \(binding.id + 1)")
                            }
                            Button(model.recording == binding.id ? "Abbrechen" : binding.shortcut.label) {
                                if model.recording == binding.id { model.cancelRecording() }
                                else { model.startRecording(binding.id) }
                            }.font(.system(.body, design: .monospaced)).frame(width: 120)
                                .help("Klicken und neue Tastenkombination drücken")
                                .accessibilityLabel("Shortcut für Ziel \(binding.id + 1): \(binding.shortcut.label)")
                            Button { model.jump(binding.id) } label: { Image(systemName: "location.fill") }
                                .help("Mauszeiger jetzt hierhin bewegen")
                                .accessibilityLabel("Ziel \(binding.id + 1) testen")
                                .disabled(!model.displays.contains(where: { $0.id == binding.displayUUID }) || model.recording != nil)
                        }
                        if let error = model.errors[binding.id] {
                            Text(error).font(.caption).foregroundStyle(.red)
                        }
                    }.padding(14).background(.background, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            Text(model.notice.isEmpty ? "Zum Ändern auf einen Shortcut klicken. Änderungen werden automatisch gespeichert." : model.notice)
                .font(.callout).foregroundStyle(model.recording == nil ? .secondary : .primary)
                .frame(height: 42, alignment: .topLeading)
            Divider()
            HStack {
                Button("Standard-Shortcuts") { model.resetShortcuts() }
                Spacer()
                Text("Läuft weiter in der Menüleiste.").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(26).frame(width: 700).background(Color(nsColor: .windowBackgroundColor))
    }
}
