//
//  ExerciseDetailView.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Scheda di un esercizio del catalogo (ADR-0005): immagine, gruppi
//  muscolari, attrezzo, istruzioni e — se presente — la dimostrazione
//  video (`Exercise.videoURL`) mostrata in-app (ADR-0013: "solo da mostrare
//  in UI durante la serie"). Stile Glass Dark (ADR-0023).
//

import SwiftUI

struct ExerciseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise

    @State private var showVideo = false

    private var videoURL: URL? {
        guard let s = exercise.videoURL, !s.isEmpty else { return nil }
        return URL(string: s)
    }
    private var imageURL: URL? {
        guard let s = exercise.imageURL, !s.isEmpty else { return nil }
        return URL(string: s)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    media
                    if !exercise.muscleGroups.isEmpty {
                        FlowChips(items: exercise.muscleGroups.map { $0.capitalized })
                    }
                    if let eq = exercise.equipment, !eq.isEmpty {
                        infoRow(icon: "wrench.and.screwdriver", text: eq.capitalized)
                    }
                    infoRow(icon: "tag", text: sourceLabel)

                    if let instr = exercise.instructions, !instr.isEmpty {
                        SectionLabel(text: "Esecuzione")
                        Text(instr)
                            .font(Glass.body(14))
                            .foregroundStyle(Glass.ink.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Nessuna istruzione salvata per questo esercizio.")
                            .font(Glass.body(13)).foregroundStyle(Glass.ink.opacity(0.45))
                    }
                }
                .padding(.horizontal, 22).padding(.top, 6).padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .glassScreen()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showVideo) {
            if let videoURL {
                VStack(spacing: 0) {
                    HStack {
                        Text(exercise.name).font(Glass.display(15, .semibold)).lineLimit(1)
                        Spacer()
                        Button("Chiudi") { showVideo = false }
                            .font(Glass.body(14, .semibold)).foregroundStyle(Glass.amberText)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 14)
                    WebView(url: videoURL)
                }
                .glassScreen()
                .presentationDetents([.large])
            }
        }
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
            Text(exercise.name).font(Glass.display(16, .semibold)).lineLimit(1)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 4)
    }

    @ViewBuilder
    private var media: some View {
        ZStack {
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFit()
                    case .failure:
                        tilePlaceholder
                    default:
                        ProgressView().frame(maxWidth: .infinity, minHeight: 180)
                    }
                }
            } else {
                tilePlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 180, maxHeight: 240)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.05)))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            if videoURL != nil {
                Button { showVideo = true } label: {
                    Label("Dimostrazione", systemImage: "play.fill")
                        .font(Glass.body(13, .bold))
                        .foregroundStyle(Color(red: 0.05, green: 0.06, blue: 0.09))
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(Capsule().fill(Glass.ink))
                }
                .buttonStyle(.plain)
                .padding(12)
                .accessibilityIdentifier("playDemo")
            }
        }
    }

    private var tilePlaceholder: some View {
        MuscleTile(groups: exercise.muscleGroups, size: 72)
            .frame(maxWidth: .infinity, minHeight: 180)
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Glass.ink.opacity(0.5))
                .frame(width: 20)
            Text(text).font(Glass.body(14)).foregroundStyle(Glass.ink.opacity(0.8))
        }
    }

    private var sourceLabel: String {
        switch exercise.source {
        case "wger": return "Catalogo wger"
        case "ai": return "Importato con AI"
        default: return "Creato da te"
        }
    }
}

/// Chips a scorrimento libero (wrap) per i gruppi muscolari.
struct FlowChips: View {
    let items: [String]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { t in
                    Text(t)
                        .font(Glass.body(12, .semibold))
                        .foregroundStyle(Glass.ink.opacity(0.75))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.07)))
                        .overlay(Capsule().strokeBorder(Glass.hairlineSoft))
                }
            }
        }
    }
}
