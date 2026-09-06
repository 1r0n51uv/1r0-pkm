//
//  ExerciseListView.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Catalogo esercizi (ADR-0005) — stile Glass Dark (ADR-0023).
//

import SwiftUI
import SwiftData

struct ExerciseListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.createdAt, order: .reverse) private var exercises: [Exercise]
    @State private var showAdd = false

    private var pendingCount: Int { exercises.filter { $0.syncedAt == nil }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                if exercises.isEmpty {
                    emptyState
                } else {
                    ForEach(exercises) { ex in
                        row(ex)
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
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().strokeBorder(Glass.hairline))
                }
                .accessibilityIdentifier("addExercise")
            }
        }
        .sheet(isPresented: $showAdd) {
            AddExerciseView()
                .presentationDetents([.medium, .large])
                .presentationBackground(.ultraThinMaterial)
        }
        .task {
            await GymSync.pullExercises(into: context)
            await GymSync.flushOutbox(context)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Catalogo")
                .font(Glass.display(34, .bold))
            HStack(spacing: 6) {
                Text("\(exercises.count) esercizi")
                    .font(Glass.body(14))
                    .foregroundStyle(Glass.textSecondary)
                if pendingCount > 0 {
                    Circle().fill(Glass.accent2).frame(width: 5, height: 5)
                    Text("\(pendingCount) da sincronizzare")
                        .font(Glass.body(14))
                        .foregroundStyle(Glass.accent2)
                }
            }
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ ex: Exercise) -> some View {
        GlassPanel {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(ex.name)
                        .font(Glass.body(17, .semibold))
                    if !ex.muscleGroups.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(ex.muscleGroups, id: \.self) { m in
                                Text(m)
                                    .font(Glass.body(12, .medium))
                                    .foregroundStyle(Glass.textSecondary)
                                    .padding(.horizontal, 9).padding(.vertical, 4)
                                    .background(Glass.hairline, in: Capsule())
                            }
                        }
                    }
                    if let eq = ex.equipment {
                        Text(eq)
                            .font(Glass.body(12))
                            .foregroundStyle(Glass.textSecondary)
                    }
                }
                Spacer(minLength: 0)
                if ex.syncedAt == nil {
                    Circle().fill(Glass.accent2).frame(width: 7, height: 7)
                        .accessibilityLabel("da sincronizzare")
                }
            }
        }
    }

    private var emptyState: some View {
        GlassPanel(padding: 28) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Nessun esercizio")
                    .font(Glass.display(20, .semibold))
                Text("Aggiungi il primo con \(Image(systemName: "plus")) in alto a destra. Funziona anche offline — si sincronizza da solo.")
                    .font(Glass.body(14))
                    .foregroundStyle(Glass.textSecondary)
            }
        }
    }
}
