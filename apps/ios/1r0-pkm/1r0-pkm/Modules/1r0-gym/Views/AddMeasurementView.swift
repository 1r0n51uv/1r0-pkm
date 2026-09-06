//
//  AddMeasurementView.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Registra peso + misure a nastro (ADR-0012). Offline-first: insert locale
//  + OutboxEntry "measurement.create".
//

import SwiftUI
import SwiftData

/// Misure comuni offerte in UI. Lo schema DB è a chiavi libere (jsonb): qui
/// diamo un set fisso, altre chiavi si potranno aggiungere in seguito.
struct MeasurementField: Identifiable {
    let key: String
    let title: String
    let short: String
    var id: String { key }

    static let all: [MeasurementField] = [
        .init(key: "waistCm", title: "Girovita", short: "vita"),
        .init(key: "hipCm", title: "Fianchi", short: "fianchi"),
        .init(key: "chestCm", title: "Torace", short: "torace"),
        .init(key: "armCm", title: "Braccio", short: "braccio"),
        .init(key: "thighCm", title: "Coscia", short: "coscia"),
    ]
}

struct AddMeasurementView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var weight = ""
    @State private var values: [String: String] = [:]

    private var parsedWeight: Double? {
        let w = Double(weight.replacingOccurrences(of: ",", with: "."))
        return (w ?? 0) > 0 ? w : nil
    }
    private var parsedMeasures: [String: Double] {
        var out: [String: Double] = [:]
        for f in MeasurementField.all {
            if let s = values[f.key], let n = Double(s.replacingOccurrences(of: ",", with: ".")), n > 0 {
                out[f.key] = n
            }
        }
        return out
    }
    private var canSave: Bool { parsedWeight != nil || !parsedMeasures.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Nuova rilevazione")
                    .font(Glass.display(24, .bold)).padding(.top, 8)

                GlassPanel {
                    DatePicker("Data", selection: $date, in: ...Date(), displayedComponents: .date)
                        .font(Glass.body(15))
                }

                field("PESO (kg)", text: $weight, placeholder: "78.5", id: "measWeight")

                ForEach(MeasurementField.all) { f in
                    field(f.title.uppercased() + " (cm)",
                          text: Binding(get: { values[f.key] ?? "" },
                                        set: { values[f.key] = $0 }),
                          placeholder: "—",
                          id: "meas_\(f.key)")
                }

                GlassPrimaryButton(title: "Salva", fill: Glass.green,
                                   onInk: Color(red: 0.01, green: 0.09, blue: 0.05), action: save)
                    .opacity(canSave ? 1 : 0.4)
                    .disabled(!canSave)
                    .accessibilityIdentifier("saveMeasurement")
            }
            .padding(20)
        }
        .glassScreen()
        .scrollDismissesKeyboard(.immediately)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fatto") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .accessibilityIdentifier("kbDone")
            }
        }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(Glass.body(11, .semibold)).tracking(0.6).foregroundStyle(Glass.textSecondary)
            TextField("", text: text, prompt: Text(placeholder).foregroundColor(Glass.textSecondary))
                .font(Glass.body(16))
                .keyboardType(.decimalPad)
                .padding(14)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.12)))
                .accessibilityIdentifier(id)
        }
    }

    private func save() {
        let m = BodyMeasurement(recordedAt: date, weightKg: parsedWeight, measurements: parsedMeasures)
        context.insert(m)

        var payload: [String: Any] = [
            "id": m.id.uuidString,
            "recordedAt": ISO8601DateFormatter().string(from: date),
            "measurements": parsedMeasures,
        ]
        if let w = parsedWeight { payload["weightKg"] = w }
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            context.insert(OutboxEntry(kind: "measurement.create", payload: data))
        }
        try? context.save()
        let ctx = context
        Task { await GymSync.flushOutbox(ctx) }
        dismiss()
    }
}
