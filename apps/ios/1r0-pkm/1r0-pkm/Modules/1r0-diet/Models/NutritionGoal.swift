//
//  NutritionGoal.swift
//  1r0-pkm · Modules/1r0-diet
//
//  Obiettivo calorico/macro (glossario "Nutrition Goal", ADR-0019). Tabella
//  *append-only*: ogni cambio (anche solo di modalità) inserisce una nuova
//  riga con `effectiveFrom`; l'obiettivo "corrente" è la più recente con
//  `effectiveFrom <= oggi`. Serve allo storico per i report (ADR-0020).
//

import Foundation
import SwiftData

/// Fase di allenamento dichiarata a mano sull'obiettivo (ADR-0027: `Routine`
/// non è più un'entità editabile, quindi non esiste più una "fase attiva"
/// da leggere altrove — l'utente la sceglie qui quando usa `phase_linked`).
enum RoutinePhase: String, CaseIterable, Identifiable {
    case bulk, cut, deload, maintenance
    var id: String { rawValue }
    var label: String {
        switch self {
        case .bulk: return "Bulk"
        case .cut: return "Cut"
        case .deload: return "Deload"
        case .maintenance: return "Mantenimento"
        }
    }
}

enum GoalMode: String, CaseIterable, Identifiable {
    case manual, phase_linked, tdee
    var id: String { rawValue }
    var label: String {
        switch self {
        case .manual: return "Manuale"
        case .phase_linked: return "Legato alla scheda"
        case .tdee: return "TDEE"
        }
    }
    var blurb: String {
        switch self {
        case .manual:
            return "Imposti i target a mano. Passa a “TDEE” per calcolarli da peso e attività."
        case .phase_linked:
            return "I target seguono la fase della scheda attiva (surplus in bulk, deficit in cut). Cambi fase → l'app propone il nuovo target."
        case .tdee:
            return "Stima da peso corrente e livello di attività dichiarato. Ricalcolabile su richiesta, non a ogni pesata."
        }
    }
}

enum ActivityLevel: String, CaseIterable, Identifiable {
    case sedentary, moderate, active
    var id: String { rawValue }
    var label: String {
        switch self {
        case .sedentary: return "Sedentario"
        case .moderate: return "Moderato"
        case .active: return "Attivo"
        }
    }
    /// kcal di mantenimento ≈ peso(kg) × fattore (stima grezza, ADR-0019:
    /// non serve Mifflin-St Jeor, manca comunque sesso/età/altezza).
    var factor: Double {
        switch self {
        case .sedentary: return 30
        case .moderate: return 34
        case .active: return 38
        }
    }
}

@Model
final class NutritionGoal {
    @Attribute(.unique) var id: UUID
    /// "manual" | "phase_linked" | "tdee".
    var modeRaw: String = GoalMode.manual.rawValue
    var caloriesTarget: Double = 0
    var proteinGTarget: Double = 0
    var carbsGTarget: Double = 0
    var fatGTarget: Double = 0
    var waterMlTarget: Double?
    var effectiveFrom: Date
    /// "sedentary" | "moderate" | "active" — solo per `mode == .tdee`.
    var activityLevelRaw: String?
    /// Contesto leggibile: "fase: cut", "tdee moderato @ 78.2 kg", "manuale".
    var sourceNote: String?
    var createdAt: Date
    var syncedAt: Date?

    var mode: GoalMode {
        get { GoalMode(rawValue: modeRaw) ?? .manual }
        set { modeRaw = newValue.rawValue }
    }
    var activityLevel: ActivityLevel? {
        get { activityLevelRaw.flatMap(ActivityLevel.init(rawValue:)) }
        set { activityLevelRaw = newValue?.rawValue }
    }
    var macros: Macros {
        Macros(kcal: caloriesTarget, proteinG: proteinGTarget,
               carbsG: carbsGTarget, fatG: fatGTarget)
    }
    /// Fase annotata in `sourceNote` (formato "fase: <rawValue>") per la
    /// modalità `phase_linked` — riproposta riaprendo l'obiettivo, anche
    /// dopo un pull dal backend (niente colonna dedicata).
    var notedPhase: RoutinePhase? {
        guard mode == .phase_linked, let note = sourceNote, note.hasPrefix("fase: ")
        else { return nil }
        return RoutinePhase(rawValue: String(note.dropFirst("fase: ".count)))
    }

    init(id: UUID = UUID(), mode: GoalMode, macros: Macros,
         waterMlTarget: Double? = nil, effectiveFrom: Date = .now,
         activityLevel: ActivityLevel? = nil, sourceNote: String? = nil,
         createdAt: Date = .now, syncedAt: Date? = nil) {
        self.id = id
        self.modeRaw = mode.rawValue
        self.caloriesTarget = macros.kcal
        self.proteinGTarget = macros.proteinG
        self.carbsGTarget = macros.carbsG
        self.fatGTarget = macros.fatG
        self.waterMlTarget = waterMlTarget
        self.effectiveFrom = effectiveFrom
        self.activityLevelRaw = activityLevel?.rawValue
        self.sourceNote = sourceNote
        self.createdAt = createdAt
        self.syncedAt = syncedAt
    }
}

/// Regole pure per derivare i target (ADR-0019). Nessuna dipendenza da
/// SwiftData / rete — testabili in isolamento.
enum NutritionMath {
    /// Split macro standard da un totale kcal e un peso di riferimento:
    /// proteine 2 g/kg, grassi 0.9 g/kg, carbo = resto.
    static func macros(kcal: Double, weightKg: Double) -> Macros {
        let w = max(40, weightKg)
        let protein = (2.0 * w).rounded()
        let fat = (0.9 * w).rounded()
        let carbKcal = max(0, kcal - protein * 4 - fat * 9)
        return Macros(kcal: kcal.rounded(),
                      proteinG: protein, carbsG: (carbKcal / 4).rounded(), fatG: fat)
    }

    /// TDEE ≈ peso × fattore attività.
    static func tdee(weightKg: Double, activity: ActivityLevel) -> Macros {
        macros(kcal: weightKg * activity.factor, weightKg: weightKg)
    }

    /// Aggiusta un mantenimento in base alla fase della scheda.
    static func phaseAdjusted(maintenanceKcal: Double, weightKg: Double,
                              phase: RoutinePhase?) -> Macros {
        let mult: Double
        switch phase {
        case .bulk: mult = 1.12
        case .cut: mult = 0.80
        case .deload: mult = 0.92
        case .maintenance, .none: mult = 1.0
        }
        return macros(kcal: maintenanceKcal * mult, weightKg: weightKg)
    }

    /// Quota calorica **del giorno corrente** = obiettivo di base + energia
    /// attiva letta da HealthKit (ADR-0019 amendata da ADR-0027). Non tocca la
    /// riga `nutrition_goals`. Il bonus è limitato a un tetto prudente.
    static func dailyCalorieQuota(baseKcal: Double, activeEnergyKcal: Double,
                                  maxBonusKcal: Double = 1200) -> Double {
        let bonus = max(0, min(activeEnergyKcal, maxBonusKcal))
        return (baseKcal + bonus).rounded()
    }

    /// Quota d'acqua "attesa a quest'ora": frazione del target proporzionale al
    /// tempo trascorso nella fascia diurna `[startHour, endHour]`. Prima
    /// dell'inizio ⇒ 0; dopo la fine ⇒ target pieno.
    static func waterQuotaMl(targetMl: Double, now: Date,
                             startHour: Int = 8, endHour: Int = 22,
                             calendar: Calendar = .current) -> Double {
        let h = Double(calendar.component(.hour, from: now))
            + Double(calendar.component(.minute, from: now)) / 60
        let s = Double(startHour), e = Double(endHour)
        guard e > s else { return targetMl }
        let frac = min(1, max(0, (h - s) / (e - s)))
        return (targetMl * frac).rounded()
    }
}
