//
//  ProgressTabView.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Progressi corporei (ADR-0012): peso + misure a nastro, andamento peso.
//  Stile Glass Dark (ADR-0023).
//

import SwiftUI
import SwiftData

struct ProgressTabView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \BodyMeasurement.recordedAt, order: .reverse) private var items: [BodyMeasurement]
    @State private var showAdd = false
    @State private var showHealth = false
    @State private var healthNote: String?

    private var weightPoints: [(date: Date, kg: Double)] {
        items.compactMap { m in m.weightKg.map { (m.recordedAt, $0) } }
    }
    private var trend: GymMath.WeightTrend? { GymMath.weightTrend(weightPoints) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Progressi")
                    .font(Glass.display(34, .bold))
                    .padding(.top, 8)

                if let trend {
                    trendPanel(trend)
                }

                if items.isEmpty {
                    GlassPanel(padding: 26) {
                        Text("Nessuna rilevazione. Tocca \(Image(systemName: "plus")) per registrare peso e misure.")
                            .font(Glass.body(14)).foregroundStyle(Glass.textSecondary)
                    }
                } else {
                    ForEach(items) { m in row(m) }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .glassScreen()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { importFromHealth() } label: {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().strokeBorder(Glass.hairline))
                }
                .accessibilityIdentifier("healthImport")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().strokeBorder(Glass.hairline))
                }
                .accessibilityIdentifier("addMeasurement")
            }
        }
        .sheet(isPresented: $showAdd) {
            AddMeasurementView()
                .presentationDetents([.large])
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showHealth) {
            HealthKitOnboardingView { _ in importFromHealth() }
                .presentationDetents([.medium, .large])
                .presentationBackground(.ultraThinMaterial)
        }
        .alert("Apple Salute", isPresented: .constant(healthNote != nil)) {
            Button("OK") { healthNote = nil }
        } message: { Text(healthNote ?? "") }
        .task {
            await GymSync.pullMeasurements(into: context)
            await GymSync.flushOutbox(context)
        }
    }

    private func trendPanel(_ t: GymMath.WeightTrend) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(fmt(t.latestKg)) kg")
                        .font(Glass.display(30, .bold)).monospacedDigit()
                    Spacer()
                    let up = t.deltaKg >= 0
                    Text("\(up ? "+" : "")\(fmt(t.deltaKg)) kg")
                        .font(Glass.body(14, .semibold))
                        .foregroundStyle(up ? Glass.accent2 : Glass.good)
                }
                Text(String(format: "%@%.2f kg/sett sul periodo",
                            t.perWeekKg >= 0 ? "+" : "", t.perWeekKg))
                    .font(Glass.body(12)).foregroundStyle(Glass.textSecondary)
                Sparkline(values: weightPoints.sorted { $0.date < $1.date }.map(\.kg))
                    .frame(height: 44)
            }
        }
    }

    private func row(_ m: BodyMeasurement) -> some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(m.recordedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(Glass.body(13, .medium)).foregroundStyle(Glass.textSecondary)
                    if m.source == "healthkit" {
                        Label("Salute", systemImage: "heart.fill")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 11))
                            .foregroundStyle(Glass.accent2)
                    }
                    Spacer()
                    if let w = m.weightKg {
                        Text("\(fmt(w)) kg").font(Glass.body(16, .semibold)).monospacedDigit()
                    }
                    if m.syncedAt == nil {
                        Circle().fill(Glass.accent2).frame(width: 6, height: 6)
                    }
                }
                if !m.measurements.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(m.measurements.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in
                            Text("\(label(k)) \(fmt(v))")
                                .font(Glass.body(11, .medium)).foregroundStyle(Glass.textSecondary)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Glass.hairline, in: Capsule())
                        }
                    }
                }
            }
        }
    }

    private func label(_ key: String) -> String {
        MeasurementField.all.first { $0.key == key }?.short ?? key
    }

    @MainActor
    private func importFromHealth() {
        Task { @MainActor in
            guard HealthKitService.shared.isAvailable else {
                healthNote = "HealthKit non è disponibile su questo dispositivo."
                return
            }
            guard let kg = await HealthKitService.shared.latestBodyWeightKg() else {
                // non autorizzato o nessun dato → mostra l'onboarding
                showHealth = true
                return
            }
            let m = BodyMeasurement(weightKg: kg, source: "healthkit")
            context.insert(m)
            if let data = try? JSONSerialization.data(withJSONObject: [
                "id": m.id.uuidString,
                "recordedAt": ISO8601DateFormatter().string(from: m.recordedAt),
                "weightKg": kg, "measurements": [String: Double](),
            ]) {
                context.insert(OutboxEntry(kind: "measurement.create", payload: data))
            }
            try? context.save()
            let ctx = context
            Task { await GymSync.flushOutbox(ctx) }
            healthNote = "Peso importato da Salute: \(fmt(kg)) kg."
        }
    }
    private func fmt(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(format: "%.1f", d)
    }
}

/// Micro-sparkline senza dipendenze.
struct Sparkline: View {
    let values: [Double]
    var body: some View {
        GeometryReader { geo in
            let vs = values
            if vs.count >= 2, let lo = vs.min(), let hi = vs.max(), hi > lo {
                Path { p in
                    for (i, v) in vs.enumerated() {
                        let x = geo.size.width * CGFloat(i) / CGFloat(vs.count - 1)
                        let y = geo.size.height * (1 - CGFloat((v - lo) / (hi - lo)))
                        i == 0 ? p.move(to: .init(x: x, y: y)) : p.addLine(to: .init(x: x, y: y))
                    }
                }
                .stroke(Glass.accent, style: .init(lineWidth: 2, lineCap: .round, lineJoin: .round))
            } else {
                Rectangle().fill(Glass.hairline).frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
        }
    }
}
