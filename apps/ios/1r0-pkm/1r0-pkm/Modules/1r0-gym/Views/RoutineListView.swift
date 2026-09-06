//
//  RoutineListView.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Lista schede con badge di fase (ADR-0015) — stile Glass Dark (ADR-0023).
//

import SwiftUI
import SwiftData

struct RoutineListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Routine.createdAt, order: .reverse) private var routines: [Routine]
    @State private var showAdd = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                if routines.isEmpty {
                    GlassPanel(padding: 28) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nessuna scheda")
                                .font(Glass.display(20, .semibold))
                            Text("Crea la prima con \(Image(systemName: "plus")). Assegna una fase (bulk/cut/deload) per orientare la progressione.")
                                .font(Glass.body(14))
                                .foregroundStyle(Glass.textSecondary)
                        }
                    }
                } else {
                    ForEach(routines) { r in
                        NavigationLink { RoutineDetailView(routine: r) } label: { card(r) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .glassScreen()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().strokeBorder(Glass.hairline))
                }
                .accessibilityIdentifier("addRoutine")
            }
        }
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
        VStack(alignment: .leading, spacing: 4) {
            Text("Schede")
                .font(Glass.display(34, .bold))
            Text("\(routines.count) schede")
                .font(Glass.body(14))
                .foregroundStyle(Glass.textSecondary)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func card(_ r: Routine) -> some View {
        GlassPanel {
            HStack(alignment: .center, spacing: 12) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Glass.phaseColor(r.phaseRaw))
                    .frame(width: 5, height: 44)
                VStack(alignment: .leading, spacing: 6) {
                    Text(r.name)
                        .font(Glass.body(18, .semibold))
                    if let phase = r.phase {
                        Text(phase.label.uppercased())
                            .font(Glass.body(11, .bold))
                            .tracking(0.8)
                            .foregroundStyle(Glass.bg)
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(Glass.phaseColor(r.phaseRaw), in: Capsule())
                    } else {
                        Text("nessuna fase")
                            .font(Glass.body(12))
                            .foregroundStyle(Glass.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                if r.syncedAt == nil {
                    Circle().fill(Glass.accent2).frame(width: 7, height: 7)
                        .accessibilityLabel("da sincronizzare")
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Glass.textSecondary)
            }
        }
    }
}
