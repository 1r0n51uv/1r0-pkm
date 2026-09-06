//
//  DietReportView.swift
//  1r0-pkm · Modules/1r0-diet
//
//  Report/andamento del modulo dieta (ADR-0020): calorie/macro nel tempo,
//  aderenza al target (con l'obiettivo storicamente attivo), correlazione
//  peso/calorie. Tutto calcolato lato client (`DietReport`), nessuna nuova
//  tabella. Layout dal mockup "GlassDietReports".
//

import SwiftUI
import SwiftData

struct DietReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MealEntry.consumedAt, order: .reverse) private var meals: [MealEntry]
    @Query(sort: \NutritionGoal.effectiveFrom, order: .reverse) private var goals: [NutritionGoal]
    @Query(sort: \BodyMeasurement.recordedAt, order: .reverse) private var measurements: [BodyMeasurement]

    @State private var days = 30

    private var series: [DietReport.Day] {
        DietReport.dailySeries(meals: meals, goals: goals, days: days)
    }
    private var currentGoalKcal: Double? { DietReport.goalActive(goals, on: .now)?.caloriesTarget }
    private var weight: [DietReport.WeightPoint] {
        DietReport.weightSeries(measurements, days: days)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    rangePills
                    calorieCard
                    section("Aderenza al piano") { adherenceCard }
                    section("Peso e calorie") { weightCard }
                }
                .padding(.horizontal, 22).padding(.top, 4).padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .glassScreen(.cool)
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Glass.ink.opacity(0.75))
                    .frame(width: 44, height: 44, alignment: .leading)
            }
            Spacer()
            Text("Andamento").font(Glass.display(16, .semibold))
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 4)
    }

    private var rangePills: some View {
        HStack(spacing: 8) {
            ForEach([30, 90], id: \.self) { d in
                Button { days = d } label: {
                    Text("\(d) giorni")
                        .font(Glass.body(13, days == d ? .bold : .semibold))
                        .foregroundStyle(days == d ? Glass.ink : Glass.ink.opacity(0.5))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background { if days == d { Capsule().fill(Color.white.opacity(0.10)) } }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: calories

    private var calorieCard: some View {
        let s = series
        let avg = DietReport.averageKcal(s)
        let trend = DietReport.trendKcal(s)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Media calorie giornaliere")
                        .font(Glass.body(12)).foregroundStyle(Glass.ink.opacity(0.5))
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(avg > 0 ? "\(Int(avg.rounded()))" : "—")
                            .font(Glass.display(26, .bold)).monospacedDigit()
                        Text("kcal").font(Glass.body(13)).foregroundStyle(Glass.ink.opacity(0.4))
                    }
                }
                Spacer()
                if let trend, let goal = currentGoalKcal {
                    let toward = abs(avg + trend - goal) < abs(avg - goal)
                    let c = toward ? Glass.green : Glass.amber
                    HStack(spacing: 4) {
                        Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(trend >= 0 ? "+" : "")\(Int(trend.rounded())) kcal")
                            .font(Glass.body(12, .bold))
                    }
                    .foregroundStyle(c)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(c.opacity(0.16)))
                    .overlay(Capsule().strokeBorder(c.opacity(0.4)))
                }
            }

            MiniLineChart(values: s.map(\.kcal),
                          drawn: s.map(\.logged),
                          color: Glass.ink.opacity(0.55),
                          target: currentGoalKcal)
                .frame(height: 90)

            if let goal = currentGoalKcal {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 1).fill(Glass.amber.opacity(0.7))
                        .frame(width: 14, height: 2)
                    Text("obiettivo \(Int(goal)) kcal")
                        .font(Glass.body(11)).foregroundStyle(Glass.ink.opacity(0.45))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(corner: 26)
    }

    // MARK: adherence

    private var adherenceCard: some View {
        let a = DietReport.adherence(series)
        return HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.10), lineWidth: 5)
                Circle().trim(from: 0, to: a.pct)
                    .stroke(Glass.green, style: .init(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int((a.pct * 100).rounded()))%")
                    .font(Glass.display(13, .bold)).monospacedDigit()
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(a.total == 0 ? "Nessun giorno valutabile"
                     : "\(a.inTarget) giorni su \(a.total) nel target")
                    .font(Glass.body(14, .semibold))
                Text(a.total == 0 ? "Serve un obiettivo e almeno un pasto loggato."
                     : "Considerato ±150 kcal dall'obiettivo")
                    .font(Glass.body(12)).foregroundStyle(Glass.ink.opacity(0.5))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .glassRow(corner: 20)
    }

    // MARK: weight

    private var weightCard: some View {
        let w = weight
        let delta = DietReport.weightDelta(w)
        return VStack(alignment: .leading, spacing: 10) {
            if w.count >= 2 {
                MiniLineChart(values: w.map(\.kg), drawn: w.map { _ in true },
                              color: Glass.blue, target: nil)
                    .frame(height: 70)
                HStack {
                    Text(deltaBlurb(delta))
                        .font(Glass.body(12)).foregroundStyle(Glass.ink.opacity(0.5))
                    Spacer()
                    if let delta {
                        Text("\(delta >= 0 ? "+" : "")\(fmt(delta)) kg")
                            .font(Glass.body(12, .bold)).foregroundStyle(Glass.blueLight)
                    }
                }
            } else {
                Text("Registra il peso più volte nei Progressi per vedere la correlazione con le calorie.")
                    .font(Glass.body(13)).foregroundStyle(Glass.ink.opacity(0.5))
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .glassRow(corner: 20)
    }

    // MARK: helpers

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: title)
            content()
        }
    }

    private func deltaBlurb(_ delta: Double?) -> String {
        guard let delta else { return "Andamento del peso nel periodo" }
        if delta <= -0.3 { return "Peso in calo nel periodo" }
        if delta >= 0.3 { return "Peso in aumento nel periodo" }
        return "Peso stabile nel periodo"
    }
    private func fmt(_ d: Double) -> String { d == d.rounded() ? String(Int(d)) : String(format: "%.1f", d) }
}

/// Line chart minimale (nessuna dipendenza da Swift Charts). `drawn`
/// nasconde i punti dei giorni senza dato. `target` disegna una linea
/// tratteggiata ambra.
struct MiniLineChart: View {
    let values: [Double]
    let drawn: [Bool]
    let color: Color
    let target: Double?

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            ZStack {
                let yr = range()
                if let target, yr.hi > yr.lo {
                    let y = geo.size.height * (1 - CGFloat((target - yr.lo) / (yr.hi - yr.lo)))
                    if y >= 0, y <= geo.size.height {
                        Path { p in p.move(to: .init(x: 0, y: y)); p.addLine(to: .init(x: geo.size.width, y: y)) }
                            .stroke(Glass.amber.opacity(0.55), style: .init(lineWidth: 1.5, dash: [4, 4]))
                    }
                }
                if pts.count >= 2 {
                    Path { p in
                        p.move(to: pts[0])
                        pts.dropFirst().forEach { p.addLine(to: $0) }
                    }
                    .stroke(color, style: .init(lineWidth: 2, lineCap: .round, lineJoin: .round))
                } else {
                    Rectangle().fill(Glass.hairlineSoft).frame(height: 1)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
            }
        }
    }

    private func range() -> (lo: Double, hi: Double) {
        var vals = values.enumerated().filter { drawn[safe: $0.offset] ?? true }.map(\.element)
        if let t = target { vals.append(t) }
        let lo = vals.min() ?? 0, hi = vals.max() ?? 1
        let pad = (hi - lo) * 0.12
        return (lo - pad, hi + pad)
    }

    private func points(in size: CGSize) -> [CGPoint] {
        let yr = range()
        guard yr.hi > yr.lo, values.count >= 2 else { return [] }
        return values.enumerated().compactMap { i, v in
            guard drawn[safe: i] ?? true else { return nil }
            let x = size.width * CGFloat(i) / CGFloat(values.count - 1)
            let y = size.height * (1 - CGFloat((v - yr.lo) / (yr.hi - yr.lo)))
            return CGPoint(x: x, y: y)
        }
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
