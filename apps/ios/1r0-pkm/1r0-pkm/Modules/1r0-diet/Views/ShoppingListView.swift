//
//  ShoppingListView.swift
//  1r0-pkm · Modules/1r0-diet
//
//  Lista della spesa (ADR-0017 slice 3): persistente e spuntabile,
//  generabile dai pasti pianificati della settimana (solo aggiunta, mai
//  rigenerazione). Stile Glass Dark (ADR-0023), accento ambra.
//

import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \ShoppingListItem.createdAt) private var items: [ShoppingListItem]
    @Query private var planned: [PlannedMeal]

    @State private var newItem = ""
    @State private var note: String?

    private var pending: [ShoppingListItem] { items.filter { !$0.isChecked } }
    private var done: [ShoppingListItem] { items.filter { $0.isChecked } }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    addRow
                    if let note {
                        Text(note).font(Glass.body(12)).foregroundStyle(Glass.amberText)
                    }
                    if items.isEmpty {
                        GlassEmptyState(systemImage: "cart",
                                        title: "Lista vuota",
                                        message: "Aggiungi voci a mano o generale dai pasti pianificati della settimana.") {
                            Button { generate() } label: {
                                Label("Genera dalla settimana", systemImage: "wand.and.stars")
                                    .font(Glass.body(14, .bold)).foregroundStyle(Glass.amberText)
                            }
                            .accessibilityIdentifier("generateShopping")
                        }
                        .frame(minHeight: 320)
                    } else {
                        if !pending.isEmpty {
                            VStack(spacing: 8) { ForEach(pending) { row($0) } }
                        }
                        if !done.isEmpty {
                            HStack {
                                SectionLabel(text: "Nel carrello")
                                Spacer()
                                Button("Svuota") { clearChecked() }
                                    .font(Glass.body(12, .semibold))
                                    .foregroundStyle(Glass.ink.opacity(0.5))
                                    .accessibilityIdentifier("clearChecked")
                            }
                            VStack(spacing: 8) { ForEach(done) { row($0) } }
                        }
                        Button { generate() } label: {
                            Label("Genera dai pasti pianificati", systemImage: "wand.and.stars")
                                .font(Glass.body(13, .semibold)).foregroundStyle(Glass.ink.opacity(0.6))
                                .frame(maxWidth: .infinity).frame(height: 46)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.05)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("generateShopping")
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 22).padding(.top, 6).padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .glassScreen(.warm)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await DietSync.pullShoppingList(into: context)
            await GymSync.flushOutbox(context)
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
            Text("Lista della spesa").font(Glass.display(16, .semibold))
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 4)
    }

    private var addRow: some View {
        HStack(spacing: 10) {
            TextField("", text: $newItem,
                      prompt: Text("Aggiungi una voce…").foregroundColor(Glass.ink.opacity(0.42)))
                .font(Glass.body(15))
                .padding(.horizontal, 16).frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.06)))
                .accessibilityIdentifier("newShoppingItem")
                .onSubmit(add)
            Button(action: add) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(red: 0.12, green: 0.06, blue: 0))
                    .frame(width: 50, height: 50)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Glass.amber))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("addShoppingItem")
        }
    }

    @MainActor
    private func row(_ it: ShoppingListItem) -> some View {
        HStack(spacing: 12) {
            Button {
                DietSync.setShoppingChecked(it, !it.isChecked, in: context)
            } label: {
                Image(systemName: it.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(it.isChecked ? Glass.green : Glass.ink.opacity(0.35))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("check_\(it.displayName)")
            VStack(alignment: .leading, spacing: 2) {
                Text(it.displayName)
                    .font(Glass.body(14, .semibold))
                    .strikethrough(it.isChecked)
                    .foregroundStyle(Glass.ink.opacity(it.isChecked ? 0.4 : 0.9))
                    .lineLimit(1)
                if let q = it.quantityText, !q.isEmpty {
                    Text(q).font(Glass.body(11)).foregroundStyle(Glass.ink.opacity(0.4))
                }
            }
            Spacer(minLength: 4)
            if it.source == .generated {
                Image(systemName: "calendar")
                    .font(.system(size: 11)).foregroundStyle(Glass.ink.opacity(0.3))
            }
            Button {
                DietSync.deleteShoppingItem(it, in: context)
            } label: {
                Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Glass.ink.opacity(0.3))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .glassRow(corner: 14)
    }

    @MainActor
    private func add() {
        let n = newItem.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        DietSync.addShoppingItem(name: n, in: context)
        newItem = ""
    }

    @MainActor
    private func generate() {
        let added = DietSync.generateShoppingList(from: planned, existing: items, in: context)
        note = added == 0 ? "Niente da aggiungere: la lista è già allineata ai pasti pianificati."
                          : "Aggiunte \(added) voci dai pasti pianificati."
    }

    @MainActor
    private func clearChecked() {
        for it in done { DietSync.deleteShoppingItem(it, in: context) }
        Task { try? await ApiClient.shared.post("v1/shopping-list/clear-checked", json: Data("{}".utf8)) }
    }
}
