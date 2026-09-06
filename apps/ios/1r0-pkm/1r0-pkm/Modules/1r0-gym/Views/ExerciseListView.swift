//
//  ExerciseListView.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Catalogo esercizi (ADR-0005) — stile Glass Dark (ADR-0023), layout dal
//  mockup "GlassExercisePicker": campo di ricerca vetro, chip per gruppo
//  muscolare, righe compatte con tile icona colorato, CTA import AI a fondo
//  lista, stato "nessun risultato" dedicato.
//

import SwiftUI
import SwiftData

struct ExerciseListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.createdAt, order: .reverse) private var exercises: [Exercise]
    @State private var showAdd = false
    @State private var showImport = false
    @State private var search = ""
    @State private var group: String? = nil          // filtro gruppo muscolare

    private var pendingCount: Int { exercises.filter { $0.syncedAt == nil }.count }

    /// Gruppi muscolari presenti a catalogo, per frequenza, primi 6.
    private var groups: [String] {
        var freq: [String: Int] = [:]
        for e in exercises { for m in e.muscleGroups { freq[m, default: 0] += 1 } }
        return freq.sorted { $0.value > $1.value || ($0.value == $1.value && $0.key < $1.key) }
            .prefix(6).map(\.key)
    }

    private var filtered: [Exercise] {
        let q = search.lowercased().trimmingCharacters(in: .whitespaces)
        return exercises.filter { e in
            let mText = e.muscleGroups.map { $0.lowercased() }
            let matchesQuery = q.isEmpty
                || e.name.lowercased().contains(q)
                || mText.contains { $0.contains(q) }
            let matchesGroup = group == nil || e.muscleGroups.contains(group!)
            return matchesQuery && matchesGroup
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if exercises.isEmpty {
                    emptyState.padding(.top, 80)
                } else {
                    GlassField(placeholder: "Cerca un esercizio…", text: $search,
                               identifier: "exerciseSearch")

                    if !groups.isEmpty { chips }

                    if filtered.isEmpty {
                        noResults.padding(.top, 60)
                    } else {
                        Text("\(filtered.count) eserciz\(filtered.count == 1 ? "io" : "i")")
                            .font(Glass.body(11)).foregroundStyle(Glass.textFaint)
                            .padding(.leading, 4)
                        VStack(spacing: 10) {
                            ForEach(filtered) { row($0) }
                        }
                        importCTA
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .glassScreen()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                toolbarButton("square.and.arrow.down") { showImport = true }
                    .accessibilityIdentifier("importExercise")
            }
            ToolbarItem(placement: .topBarTrailing) {
                toolbarButton("plus") { showAdd = true }
                    .accessibilityIdentifier("addExercise")
            }
        }
        .sheet(isPresented: $showAdd) {
            AddExerciseView()
                .presentationDetents([.medium, .large])
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showImport) {
            ImportExerciseView()
                .presentationDetents([.large])
                .presentationBackground(.ultraThinMaterial)
        }
        .task {
            await GymSync.pullExercises(into: context)
            await GymSync.flushOutbox(context)
        }
    }

    private func toolbarButton(_ name: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Glass.ink)
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Glass.hairline))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Catalogo")
                .font(Glass.display(28, .bold)).tracking(-0.5)
            HStack(spacing: 6) {
                Text("\(exercises.count) eserciz\(exercises.count == 1 ? "io" : "i")")
                    .font(Glass.body(14)).foregroundStyle(Glass.textSecondary)
                if pendingCount > 0 {
                    Circle().fill(Glass.amber).frame(width: 5, height: 5)
                    Text("\(pendingCount) in coda")
                        .font(Glass.body(14)).foregroundStyle(Glass.amberText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                GlassChip(label: "Tutti", selected: group == nil,
                          tint: Glass.coral) { group = nil }
                ForEach(groups, id: \.self) { g in
                    let (c, _) = Glass.muscleHues([g])
                    GlassChip(label: g.capitalized, selected: group == g,
                              tint: c) { group = (group == g ? nil : g) }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func row(_ ex: Exercise) -> some View {
        HStack(spacing: 14) {
            MuscleTile(groups: ex.muscleGroups, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(ex.name)
                    .font(Glass.body(14, .semibold))
                    .lineLimit(1)
                Text(subtitle(ex))
                    .font(Glass.body(12))
                    .foregroundStyle(Glass.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            sourceBadge(ex.source)
            if ex.syncedAt == nil {
                Circle().fill(Glass.amber).frame(width: 6, height: 6)
                    .accessibilityLabel("in coda")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassRow()
    }

    private func subtitle(_ ex: Exercise) -> String {
        var parts: [String] = []
        if let eq = ex.equipment, !eq.isEmpty { parts.append(eq) }
        if !ex.muscleGroups.isEmpty { parts.append(ex.muscleGroups.joined(separator: ", ")) }
        return parts.isEmpty ? "Esercizio personale" : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func sourceBadge(_ source: String) -> some View {
        if source != "custom" {
            let isWger = source == "wger"
            Text(isWger ? "wger" : "AI")
                .font(Glass.body(9, .bold)).tracking(0.4)
                .foregroundStyle(isWger ? Glass.textSecondary : Glass.purpleText)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background((isWger ? Color.white.opacity(0.10) : Glass.purple.opacity(0.18)), in: Capsule())
        }
    }

    private var importCTA: some View {
        Button { showImport = true } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 40, height: 40)
                    .overlay(Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Glass.amber))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Non trovi l'esercizio?")
                        .font(Glass.body(13, .semibold))
                    Text("Cercalo con l'AI e conferma i dati")
                        .font(Glass.body(12)).foregroundStyle(Glass.ink.opacity(0.5))
                }
                Spacer(minLength: 4)
                Text("Importa")
                    .font(Glass.body(12, .bold)).foregroundStyle(Glass.amberText)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Glass.hairline, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }

    private var noResults: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 72, height: 72)
                .overlay(Circle().strokeBorder(Glass.hairlineSoft))
                .overlay(Image(systemName: "magnifyingglass")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(Glass.ink.opacity(0.4)))
            VStack(spacing: 4) {
                Text("Nessun risultato").font(Glass.display(16, .semibold))
                Text("Prova con un altro nome, o crealo tu")
                    .font(Glass.body(13)).foregroundStyle(Glass.ink.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            Button { showAdd = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Crea nuovo")
                }
                .font(Glass.body(14, .semibold)).foregroundStyle(Glass.ink)
                .padding(.horizontal, 20).frame(height: 48)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Glass.hairline))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        GlassEmptyState(
            systemImage: "dumbbell.fill",
            title: "Catalogo vuoto",
            message: "Aggiungi il primo esercizio, o importa il catalogo wger. Funziona offline — si sincronizza da solo."
        ) {
            VStack(spacing: 10) {
                GlassPrimaryButton(title: "Aggiungi esercizio", systemImage: "plus") { showAdd = true }
                    .fixedSize(horizontal: true, vertical: false)
                Button("Importa dal catalogo") { showImport = true }
                    .font(Glass.body(13, .semibold))
                    .foregroundStyle(Glass.amberText)
            }
        }
    }
}
