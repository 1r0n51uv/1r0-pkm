//
//  RoutineListView.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Lista schede con badge di fase (ADR-0015) — stile Glass Dark (ADR-0023),
//  layout dal mockup "Main": header inline, card con tile colorato per fase,
//  pill di fase, riga meta (giorni · esercizi).
//

import SwiftUI
import SwiftData

struct RoutineListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Routine.createdAt, order: .reverse) private var routines: [Routine]
    @Query(sort: \RoutineDay.orderIndex) private var allDays: [RoutineDay]
    @Query(sort: \RoutineExercise.orderIndex) private var allExercises: [RoutineExercise]
    @State private var showAdd = false

    private func dayCount(_ r: Routine) -> Int { allDays.filter { $0.routine?.id == r.id }.count }
    private func exCount(_ r: Routine) -> Int {
        let dayIds = Set(allDays.filter { $0.routine?.id == r.id }.map(\.id))
        return allExercises.filter { $0.day.map { dayIds.contains($0.id) } ?? false }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if routines.isEmpty {
                    emptyState.padding(.top, 72)
                } else {
                    VStack(spacing: 12) {
                        ForEach(routines) { r in
                            NavigationLink { RoutineDetailView(routine: r) } label: { card(r) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .glassScreen()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAdd) {
            AddRoutineView()
                .presentationDetents([.medium])
                .presentationBackground(.ultraThinMaterial)
        }
        .task {
            await GymSync.pullRoutines(into: context)
            await GymSync.flushOutbox(context)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Schede")
                    .font(Glass.display(28, .bold)).tracking(-0.5)
                Text("\(routines.count) sched\(routines.count == 1 ? "a" : "e")")
                    .font(Glass.body(14)).foregroundStyle(Glass.textSecondary)
            }
            Spacer(minLength: 8)
            GlassIconButton(systemName: "plus") { showAdd = true }
                .accessibilityIdentifier("addRoutine")
        }
    }

    private func card(_ r: Routine) -> some View {
        let phaseHue = Glass.phaseColor(r.phaseRaw)
        return HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(LinearGradient(colors: [phaseHue.opacity(0.9), phaseHue.opacity(0.45)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 18, weight: .bold)).foregroundStyle(.white))
                .shadow(color: phaseHue.opacity(0.35), radius: 10, y: 6)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(r.name).font(Glass.display(16, .semibold)).lineLimit(1)
                    if let p = r.phase { PhasePill(text: p.label, color: phaseHue) }
                }
                Text(meta(r))
                    .font(Glass.body(12)).foregroundStyle(Glass.ink.opacity(0.45))
            }
            Spacer(minLength: 4)
            if r.syncedAt == nil {
                Circle().fill(Glass.amber).frame(width: 6, height: 6)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Glass.ink.opacity(0.35))
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .glassRow()
    }

    private func meta(_ r: Routine) -> String {
        let d = dayCount(r), e = exCount(r)
        let dTxt = "\(d) giorn\(d == 1 ? "o" : "i")"
        let eTxt = "\(e) eserciz\(e == 1 ? "io" : "i")"
        return d == 0 ? "Nessun giorno · tocca per aggiungere" : "\(dTxt) · \(eTxt)"
    }

    private var emptyState: some View {
        GlassEmptyState(
            systemImage: "square.stack.3d.up.fill",
            title: "Nessuna scheda ancora",
            message: "Crea la tua prima scheda, un giorno alla volta, con gli esercizi che vuoi allenare."
        ) {
            GlassPrimaryButton(title: "Crea la prima scheda", systemImage: "plus") { showAdd = true }
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}
