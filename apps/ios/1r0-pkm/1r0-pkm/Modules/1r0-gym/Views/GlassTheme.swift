//
//  GlassTheme.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Linguaggio visivo "Glass Dark" (ADR-0023). Token e componenti allineati
//  1:1 al canvas dei mockup ("1r0 - Direzione Glass Dark"):
//   - fondo #0A0C10 + 2/3 radial-gradient ancorati ai bordi (non cerchi
//     sfocati): il contenuto scorre, i blob no;
//   - vetro coerente a qualsiasi altezza: overlay bianco ~5.5% + material +
//     hairline chiara + luce speculare in alto + ombra netta;
//   - palette per gruppo muscolare / semantica in tinte oklch tradotte in
//     sRGB (corallo 25°, blu 250°, viola 305°, ambra 55/70°, verde 150°);
//   - primario = fill pieno saturo con inchiostro quasi-nero (mai gradiente
//     slavato); pill di fase traslucida e non a tinta piena.
//

import SwiftUI

enum Glass {

    // MARK: Fondo e inchiostro

    /// Fondo schermata (canvas: `#0A0C10`).
    static let bg = Color(red: 0.039, green: 0.047, blue: 0.063)
    /// Compat: superficie "elevata" — ora è il fondo stesso, il rilievo lo
    /// danno i pannelli vetro.
    static let bgElevated = Color(red: 0.055, green: 0.063, blue: 0.082)

    /// Inchiostro base sul fondo scuro (canvas: `#F5F6F8`).
    static let ink = Color(red: 0.961, green: 0.965, blue: 0.973)
    static let textPrimary = ink
    static let textSecondary = ink.opacity(0.60)
    static let textTertiary = ink.opacity(0.46)
    static let textFaint = ink.opacity(0.40)

    /// Bordo/hairline dei pannelli (canvas: `rgba(255,255,255,0.14)`).
    static let hairline = Color.white.opacity(0.14)
    /// Hairline tenue per righe e input secondari.
    static let hairlineSoft = Color.white.opacity(0.10)

    // MARK: Palette accento (oklch → sRGB, dal canvas)

    /// Corallo 25° — accento primario, CTA, "Salva".
    static let coral = Color(red: 0.937, green: 0.451, blue: 0.408)          // oklch(72% .17 25)
    static let coralLight = Color(red: 1.000, green: 0.557, blue: 0.525)     // oklch(78% .15 25)
    static let coralDark = Color(red: 0.765, green: 0.310, blue: 0.294)      // oklch(58% .15 25)
    /// Inchiostro su fill corallo (canvas: `#1A0B06`).
    static let onCoral = Color(red: 0.102, green: 0.043, blue: 0.024)

    static let blue = Color(red: 0.325, green: 0.639, blue: 0.949)          // oklch(70% .14 250)
    static let blueLight = Color(red: 0.427, green: 0.714, blue: 1.000)
    static let blueDark = Color(red: 0.067, green: 0.420, blue: 0.710)
    static let onBlue = Color(red: 0.020, green: 0.039, blue: 0.094)         // #050A18

    static let purple = Color(red: 0.737, green: 0.533, blue: 0.957)        // oklch(72% .16 305)
    static let purpleLight = Color(red: 0.800, green: 0.624, blue: 1.000)
    static let purpleText = Color(red: 0.867, green: 0.741, blue: 1.000)    // oklch(85% .10 305)

    static let amber = Color(red: 0.953, green: 0.682, blue: 0.345)         // oklch(80% .13 70) warn
    static let amberText = Color(red: 0.980, green: 0.780, blue: 0.500)

    static let green = Color(red: 0.325, green: 0.745, blue: 0.439)         // oklch(72% .15 150)
    static let greenText = Color(red: 0.596, green: 0.886, blue: 0.659)     // oklch(85% .11 150)

    // Compat con i call-site esistenti.
    static let accent = coral
    static let accent2 = purple
    static let good = green

    // MARK: Raggi

    /// Compat generico (era 22). I mockup usano 30 per le card, 18 per le
    /// righe, 16 per i controlli.
    static let corner: CGFloat = 26
    static let cardCorner: CGFloat = 30
    static let rowCorner: CGFloat = 18
    static let controlCorner: CGFloat = 16

    // MARK: Fase routine (ADR-0015) — tinte oklch del canvas

    /// Colore "vivo" della fase (dot, rail).
    static func phaseColor(_ phase: String?) -> Color {
        switch phase {
        case "bulk": return blueLight
        case "cut": return coralLight
        case "deload": return purpleLight
        case "maintenance": return greenText
        default: return ink.opacity(0.35)
        }
    }

    // MARK: Palette per gruppo muscolare (icon tile, ADR-0023)

    /// Coppia (chiara, scura) per il gradiente 160° del tile icona.
    static func muscleHues(_ groups: [String]) -> (Color, Color) {
        let g = groups.map { $0.lowercased() }
        func has(_ ks: [String]) -> Bool { ks.contains { k in g.contains { $0.contains(k) } } }

        if has(["gambe", "leg", "quad", "glute", "polpacc", "femoral", "hamstring", "calf"]) {
            return (Color(red: 0.800, green: 0.624, blue: 1.000), Color(red: 0.478, green: 0.196, blue: 0.612)) // 305
        }
        if has(["dorso", "back", "schiena", "lat", "trapez", "rhomboid", "row", "pull"]) {
            return (blueLight, blueDark) // 250
        }
        if has(["spalle", "shoulder", "delt", "press", "lateral raise"]) {
            return (Color(red: 0.976, green: 0.584, blue: 0.286), Color(red: 0.655, green: 0.290, blue: 0.020)) // 55
        }
        if has(["bicip", "tricip", "curl", "arm", "braccia", "forearm", "avambracc"]) {
            return (Color(red: 0.902, green: 0.490, blue: 0.345), Color(red: 0.620, green: 0.267, blue: 0.129)) // 40
        }
        if has(["core", "addome", "abs", "oblique", "plank"]) {
            return (Color(red: 0.078, green: 0.733, blue: 0.761), Color(red: 0.000, green: 0.463, blue: 0.494)) // 200
        }
        if has(["olymp", "strappo", "slancio", "snatch", "clean", "jerk"]) {
            return (greenText, Color(red: 0.180, green: 0.510, blue: 0.286)) // 150
        }
        // petto / default
        return (coralLight, coralDark) // 25
    }

    static func muscleGradient(_ groups: [String]) -> LinearGradient {
        let (a, b) = muscleHues(groups)
        return LinearGradient(colors: [a, b], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: Font (variabili — il peso lo applica .weight)

    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .custom("Space Grotesk", size: size).weight(weight)
    }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Manrope", size: size).weight(weight)
    }
}

// MARK: - Fondo a radial-gradient

/// Tinte disponibili per il fondo, per dare contesto alla schermata
/// (canvas: Progressi vira al verde, "nessun risultato" all'ambra).
enum GlassTint { case standard, progress, warm, cool }

/// Fondo scuro + 2/3 radial-gradient ancorati ai bordi. Va in `.background`
/// della root; il contenuto ci scorre sopra senza trascinarlo.
struct GlassBackground: View {
    var tint: GlassTint = .standard

    var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            ZStack {
                Glass.bg
                ForEach(Array(blobs.enumerated()), id: \.offset) { _, b in
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: b.color, location: 0.0),
                            .init(color: b.color.opacity(0.5), location: 0.4),
                            .init(color: b.color.opacity(0), location: 1.0),
                        ]),
                        center: UnitPoint(x: b.x, y: b.y),
                        startRadius: 0,
                        endRadius: d * b.r
                    )
                }
            }
            .blur(radius: 12)
        }
        .ignoresSafeArea()
    }

    private struct Blob { let color: Color; let x: CGFloat; let y: CGFloat; let r: CGFloat }

    private var blobs: [Blob] {
        switch tint {
        case .standard:
            return [
                Blob(color: Glass.coral.opacity(0.42), x: 0.12, y: -0.04, r: 0.95),
                Blob(color: Glass.blue.opacity(0.32), x: 1.02, y: 0.14, r: 0.92),
                Blob(color: Glass.purple.opacity(0.24), x: 0.05, y: 0.86, r: 0.85),
            ]
        case .progress:
            return [
                Blob(color: Glass.green.opacity(0.38), x: 0.12, y: -0.04, r: 0.95),
                Blob(color: Glass.blue.opacity(0.26), x: 1.02, y: 0.16, r: 0.90),
            ]
        case .warm:
            return [
                Blob(color: Glass.amber.opacity(0.26), x: 0.88, y: -0.04, r: 0.92),
                Blob(color: Glass.coral.opacity(0.22), x: 0.02, y: 0.88, r: 0.85),
            ]
        case .cool:
            return [
                Blob(color: Glass.blue.opacity(0.34), x: 0.88, y: -0.04, r: 0.92),
                Blob(color: Glass.purple.opacity(0.22), x: -0.02, y: 0.92, r: 0.85),
            ]
        }
    }
}

// MARK: - Superfici vetro

/// Vetro coerente: material (blur) + tinta bianca ~5.5% + hairline chiara +
/// luce speculare in alto. `elevated` aggiunge l'ombra netta delle card.
private struct GlassSurface: ViewModifier {
    var corner: CGFloat
    var elevated: Bool
    var fillOpacity: Double = 0.055

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        return content
            .background {
                shape.fill(.ultraThinMaterial)
                    .overlay(shape.fill(Color.white.opacity(fillOpacity)))
                    // luce speculare in alto (canvas: inset 0 1px 0 rgba(255,255,255,0.08))
                    .overlay(
                        shape.fill(
                            LinearGradient(colors: [.white.opacity(0.10), .white.opacity(0), .white.opacity(0)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                    )
            }
            .overlay(
                shape.strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.30), .white.opacity(0.12)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
            )
            .clipShape(shape)
            .shadow(color: .black.opacity(elevated ? 0.40 : 0), radius: elevated ? 22 : 0, y: elevated ? 12 : 0)
    }
}

extension View {
    /// Card in rilievo (canvas: radius 30, ombra netta).
    func glassCard(corner: CGFloat = Glass.cardCorner) -> some View {
        modifier(GlassSurface(corner: corner, elevated: true, fillOpacity: 0.10))
    }
    /// Riga/tessera piatta (canvas: radius 18, niente ombra, tinta più bassa).
    func glassRow(corner: CGFloat = Glass.rowCorner) -> some View {
        modifier(GlassSurface(corner: corner, elevated: false, fillOpacity: 0.08))
    }
    /// Controllo (input, icon button): radius 16, tinta 6/7%.
    func glassControl(corner: CGFloat = Glass.controlCorner) -> some View {
        modifier(GlassSurface(corner: corner, elevated: false, fillOpacity: 0.09))
    }
}

/// Compat: pannello generico. Ora usa il vetro coerente (niente più
/// `.environment(.colorScheme, .light)` che lo faceva "sparire nel nero").
struct GlassPanel<Content: View>: View {
    var padding: CGFloat = 16
    var corner: CGFloat = Glass.corner
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(corner: corner)
    }
}

// MARK: - Componenti

/// Bottone icona 44×44 quadrato-arrotondato (canvas: radius 16, vetro 7%).
struct GlassIconButton: View {
    var systemName: String
    var tint: Color? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint == nil ? Glass.ink : Glass.onCoral)
                .frame(width: 44, height: 44)
                .background {
                    let s = RoundedRectangle(cornerRadius: Glass.controlCorner, style: .continuous)
                    if let tint {
                        s.fill(tint)
                    } else {
                        s.fill(.ultraThinMaterial).overlay(s.fill(Color.white.opacity(0.07)))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: Glass.controlCorner, style: .continuous)
                        .strokeBorder(tint == nil ? Glass.hairline : .clear)
                )
        }
        .buttonStyle(.plain)
    }
}

/// CTA primaria: fill pieno saturo + inchiostro quasi-nero (mai gradiente).
struct GlassPrimaryButton: View {
    var title: String
    var systemImage: String? = nil
    var fill: Color = Glass.coral
    var onInk: Color = Glass.onCoral
    var height: CGFloat = 52
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(Glass.display(16, .semibold))
            .foregroundStyle(onInk)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(fill, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Tile icona per gruppo muscolare: gradiente 160° nella tinta + glow.
struct MuscleTile: View {
    var groups: [String]
    var systemImage: String = "dumbbell.fill"
    var size: CGFloat = 52

    var body: some View {
        let (a, b) = Glass.muscleHues(groups)
        RoundedRectangle(cornerRadius: size * 0.34, style: .continuous)
            .fill(LinearGradient(colors: [a, b], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(.white)
            )
            .shadow(color: b.opacity(0.40), radius: 10, y: 6)
    }
}

/// Chip filtro: selezionato = fill tinta + inchiostro scuro; altrimenti vetro.
struct GlassChip: View {
    var label: String
    var selected: Bool
    var tint: Color = Glass.coral
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Glass.body(13, selected ? .bold : .semibold))
                .foregroundStyle(selected ? Glass.onCoral : Glass.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background {
                    if selected { Capsule().fill(tint) }
                    else { Capsule().fill(Color.white.opacity(0.06)) }
                }
        }
        .buttonStyle(.plain)
    }
}

/// Pill di fase: capsula traslucida tinta + bordo + dot (mai a tinta piena).
struct PhasePill: View {
    var text: String
    var color: Color
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text.uppercased())
                .font(Glass.body(11, .bold)).tracking(0.6)
                .foregroundStyle(color)
        }
        .padding(.leading, 10).padding(.trailing, 12).padding(.vertical, 5)
        .background(Capsule().fill(color.opacity(0.16)))
        .overlay(Capsule().strokeBorder(color.opacity(0.40)))
    }
}

/// Etichetta di sezione (canvas: 13/700 a ink 55%).
struct SectionLabel: View {
    var text: String
    var body: some View {
        Text(text)
            .font(Glass.body(13, .bold))
            .foregroundStyle(Glass.ink.opacity(0.55))
            .padding(.leading, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Campo di ricerca vetro (canvas: h52, radius 16, blur, hairline).
struct GlassField: View {
    var placeholder: String
    @Binding var text: String
    var identifier: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Glass.ink.opacity(0.45))
            TextField("", text: $text,
                      prompt: Text(placeholder).foregroundColor(Glass.ink.opacity(0.40)))
                .font(Glass.body(15))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier(identifier ?? placeholder)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Glass.ink.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .glassControl()
    }
}

/// Stato vuoto (canvas: tile 84 + titolo + una riga + CTA primaria).
struct GlassEmptyState<Action: View>: View {
    var systemImage: String
    var title: String
    var message: String
    @ViewBuilder var action: Action

    var body: some View {
        VStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color.white.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Glass.hairline))
                .frame(width: 84, height: 84)
                .overlay(
                    Image(systemName: systemImage)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Glass.ink.opacity(0.6))
                )
            VStack(spacing: 6) {
                Text(title).font(Glass.display(19, .bold))
                Text(message)
                    .font(Glass.body(14))
                    .foregroundStyle(Glass.ink.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            action
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Modificatore schermata

extension View {
    /// Sfondo + tipografia + tema scuro di base della schermata.
    func glassScreen(_ tint: GlassTint = .standard) -> some View {
        self
            .background(GlassBackground(tint: tint))
            .foregroundStyle(Glass.textPrimary)
            .tint(Glass.coral)
            .preferredColorScheme(.dark)
    }
}
