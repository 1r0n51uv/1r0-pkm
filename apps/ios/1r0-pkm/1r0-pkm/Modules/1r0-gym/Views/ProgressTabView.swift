//
//  ProgressTabView.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Progressi corporei (ADR-0012): peso + misure a nastro, andamento peso.
//  Stile Glass Dark (ADR-0023), layout dal mockup "GlassBodyProgress":
//  fondo verde, card andamento con sparkline ad area, misure a griglia.
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
            VStack(alignment: .leading, spacing: 18) {
                header

                if let trend { trendCard(trend) }

                if items.isEmpty {
                    emptyState.padding(.top, 56)
                } else {
                    SectionLabel(text: "Rilevazioni")
                    VStack(spacing: 10) {
                        ForEach(items) { row($0) }
                    }
                }
            }
            .padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .glassScreen(.progress)
        .toolbar(.hidden, for: .navigationBar)
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
            await Outbox.flushOutbox(context)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Progressi")
                    .font(Glass.display(28, .bold)).tracking(-0.5)
                Text("Peso, misure e foto nel tempo")
                    .font(Glass.body(14)).foregroundStyle(Glass.textSecondary)
            }
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                GlassIconButton(systemName: "heart.text.square") { importFromHealth() }
                    .accessibilityIdentifier("healthImport")
                GlassIconButton(systemName: "plus", tint: Glass.green) { showAdd = true }
                    .accessibilityIdentifier("addMeasurement")
            }
        }
    }

    private func trendCard(_ t: GymMath.WeightTrend) -> some View {
        let gain = t.deltaKg >= 0
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(fmt(t.latestKg)).font(Glass.display(34, .bold)).monospacedDigit()
                    Text("kg").font(Glass.body(14)).foregroundStyle(Glass.ink.opacity(0.5))
                }
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: gain ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(gain ? "+" : "")\(fmt(t.deltaKg)) kg").font(Glass.body(12, .bold))
                }
                .foregroundStyle(gain ? Glass.coralLight : Glass.greenText)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill((gain ? Glass.coral : Glass.green).opacity(0.16)))
                .overlay(Capsule().strokeBorder((gain ? Glass.coral : Glass.green).opacity(0.35)))
            }
            Sparkline(values: weightPoints.sorted { $0.date < $1.date }.map(\.kg), fill: true)
                .frame(height: 64)
            HStack {
                Text("inizio periodo").font(Glass.body(11)).foregroundStyle(Glass.textFaint)
                Spacer()
                Text("oggi").font(Glass.body(11)).foregroundStyle(Glass.textFaint)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func row(_ m: BodyMeasurement) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(m.recordedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(Glass.body(13, .medium)).foregroundStyle(Glass.textSecondary)
                if m.source == "healthkit" {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10)).foregroundStyle(Glass.coralLight)
                }
                Spacer()
                if let w = m.weightKg {
                    Text("\(fmt(w)) kg").font(Glass.display(16, .semibold)).monospacedDigit()
                }
                if m.syncedAt == nil {
                    Circle().fill(Glass.amber).frame(width: 6, height: 6)
                }
            }
            if !m.measurements.isEmpty {
                HStack(spacing: 6) {
                    ForEach(m.measurements.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in
                        Text("\(label(k)) \(fmt(v))")
                            .font(Glass.body(11, .medium)).foregroundStyle(Glass.textSecondary)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .glassRow()
    }

    private var emptyState: some View {
        GlassEmptyState(
            systemImage: "figure",
            title: "Nessuna rilevazione",
            message: "Registra peso e misure per vedere l'andamento nel tempo, o importa il peso da Apple Salute."
        ) {
            VStack(spacing: 10) {
                GlassPrimaryButton(title: "Registra misura", systemImage: "plus",
                                   fill: Glass.green, onInk: Color(red: 0.01, green: 0.09, blue: 0.05)) {
                    showAdd = true
                }
                .fixedSize(horizontal: true, vertical: false)
                Button("Importa da Salute") { importFromHealth() }
                    .font(Glass.body(13, .semibold)).foregroundStyle(Glass.greenText)
            }
        }
    }

    private func label(_ key: String) -> String {
        MeasurementField.all.first { $0.key == key }?.short ?? key
    }

    private func importFromHealth() {
        Task { @MainActor in
            guard HealthKitService.shared.isAvailable else {
                healthNote = "HealthKit non è disponibile su questo dispositivo."
                return
            }
            guard let kg = await HealthKitService.shared.latestBodyWeightKg() else {
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
            Task { await Outbox.flushOutbox(ctx) }
            healthNote = "Peso importato da Salute: \(fmt(kg)) kg."
        }
    }
    private func fmt(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(format: "%.1f", d)
    }
}

/// Micro-sparkline senza dipendenze. `fill` aggiunge l'area sotto la linea.
struct Sparkline: View {
    let values: [Double]
    var fill: Bool = false

    var body: some View {
        GeometryReader { geo in
            let vs = values
            if vs.count >= 2, let lo = vs.min(), let hi = vs.max(), hi > lo {
                let pts: [CGPoint] = vs.enumerated().map { i, v in
                    CGPoint(x: geo.size.width * CGFloat(i) / CGFloat(vs.count - 1),
                            y: geo.size.height * (1 - CGFloat((v - lo) / (hi - lo))))
                }
                ZStack {
                    if fill {
                        Path { p in
                            p.move(to: CGPoint(x: pts[0].x, y: geo.size.height))
                            pts.forEach { p.addLine(to: $0) }
                            p.addLine(to: CGPoint(x: pts.last!.x, y: geo.size.height))
                            p.closeSubpath()
                        }
                        .fill(LinearGradient(colors: [Glass.green.opacity(0.22), Glass.green.opacity(0)],
                                             startPoint: .top, endPoint: .bottom))
                    }
                    Path { p in
                        p.move(to: pts[0]); pts.dropFirst().forEach { p.addLine(to: $0) }
                    }
                    .stroke(Glass.green, style: .init(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }
            } else {
                Rectangle().fill(Glass.hairlineSoft).frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
        }
    }
}
