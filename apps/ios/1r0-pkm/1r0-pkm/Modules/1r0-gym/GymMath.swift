//
//  GymMath.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Regole di dominio pure (glossario: "PR / 1RM stimato", "Volume").
//  Calcolo locale, offline, nessuna AI (ADR-0011). Coperte da unit test.
//

import Foundation

enum GymMath {
    /// 1RM stimato — formula di Epley: `w * (1 + reps/30)`.
    /// A 1 rep ritorna il peso stesso. reps <= 0 o w < 0 ⇒ 0.
    static func epley1RM(weightKg w: Double, reps: Int) -> Double {
        guard w >= 0, reps > 0 else { return 0 }
        if reps == 1 { return w }
        return w * (1.0 + Double(reps) / 30.0)
    }

    /// Volume = somma di (peso × reps).
    static func volume<S: Sequence>(_ sets: S) -> Double where S.Element == (weightKg: Double, reps: Int) {
        sets.reduce(0) { $0 + $1.weightKg * Double($1.reps) }
    }

    /// Miglior 1RM stimato su un insieme di serie.
    static func bestEstimated1RM<S: Sequence>(_ sets: S) -> Double where S.Element == (weightKg: Double, reps: Int) {
        sets.reduce(0) { max($0, epley1RM(weightKg: $1.weightKg, reps: $1.reps)) }
    }
}
