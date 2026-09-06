//
//  PlateConfig.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Plate Set Config (glossario): bilanciere + dischi realmente disponibili,
//  usati dal calcolatore piastre in-sessione (ADR-0013). Riga unica.
//

import Foundation
import SwiftData

@Model
final class PlateConfig {
    /// id fisso: c'è una sola config (app single-user).
    @Attribute(.unique) var id: String
    var barWeightKg: Double
    var availablePlatesKg: [Double]
    var syncedAt: Date?

    init(
        barWeightKg: Double = 20,
        availablePlatesKg: [Double] = [1.25, 2.5, 5, 10, 15, 20, 25]
    ) {
        self.id = "singleton"
        self.barWeightKg = barWeightKg
        self.availablePlatesKg = availablePlatesKg.sorted()
        self.syncedAt = nil
    }
}
