//
//  GlassTheme.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Linguaggio visivo "Glass Dark" (ADR-0023): dark-first, pannelli traslucidi
//  con blur, sfondo a blob sfumati, angoli arrotondati uniformi, Space Grotesk
//  per numeri/titoli + Manrope per il corpo.
//

import SwiftUI

enum Glass {
    // Palette
    static let bg = Color(red: 0.043, green: 0.047, blue: 0.075)          // #0B0C13
    static let bgElevated = Color(red: 0.078, green: 0.086, blue: 0.13)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let hairline = Color.white.opacity(0.08)
    static let accent = Color(red: 0.49, green: 0.55, blue: 1.0)          // periwinkle
    static let accent2 = Color(red: 0.98, green: 0.45, blue: 0.72)        // pink
    static let good = Color(red: 0.38, green: 0.86, blue: 0.62)

    static let corner: CGFloat = 22

    /// Colore fase routine (ADR-0015).
    static func phaseColor(_ phase: String?) -> Color {
        switch phase {
        case "bulk": return Color(red: 0.45, green: 0.7, blue: 1.0)
        case "cut": return Color(red: 1.0, green: 0.55, blue: 0.42)
        case "deload": return Color(red: 0.72, green: 0.62, blue: 1.0)
        case "maintenance": return good
        default: return .white.opacity(0.35)
        }
    }

    // Fonts (variabili — il peso lo applica .fontWeight)
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .custom("Space Grotesk", size: size).weight(weight)
    }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Manrope", size: size).weight(weight)
    }
}

/// Sfondo a blob sfumati + tinta scura. Da mettere in `.background` della root.
struct GlassBackground: View {
    var body: some View {
        ZStack {
            Glass.bg
            GeometryReader { geo in
                let w = geo.size.width
                blob(Glass.accent, d: w * 1.1)
                    .position(x: w * 0.12, y: geo.size.height * 0.14)
                blob(Glass.accent2, d: w * 0.95)
                    .position(x: w * 0.95, y: geo.size.height * 0.28)
                blob(Glass.good.opacity(0.7), d: w * 0.9)
                    .position(x: w * 0.8, y: geo.size.height * 0.92)
            }
        }
        .ignoresSafeArea()
    }

    private func blob(_ c: Color, d: CGFloat) -> some View {
        Circle()
            .fill(c)
            .frame(width: d, height: d)
            .blur(radius: d * 0.32)
            .opacity(0.55)
    }
}

/// Pannello glass: material traslucido + hairline + angoli arrotondati.
struct GlassPanel<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Glass.corner, style: .continuous))
            .background(
                // sottile luce dall'alto, così i pannelli non "spariscono" sul dark
                LinearGradient(
                    colors: [.white.opacity(0.10), .white.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: Glass.corner, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Glass.corner, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.05)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    /// Applica sfondo + tipografia di base della schermata.
    func glassScreen() -> some View {
        self
            .background(GlassBackground())
            .foregroundStyle(Glass.textPrimary)
            .tint(Glass.accent)
            .preferredColorScheme(.dark)
    }
}
