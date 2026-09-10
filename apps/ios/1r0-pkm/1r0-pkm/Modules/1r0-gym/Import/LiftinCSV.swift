//
//  LiftinCSV.swift
//  1r0-pkm · Modules/1r0-gym/Import
//
//  Parser dell'export CSV dell'app Liftin' (ADR-0027). Header atteso
//  (delimitatore `;`):
//
//    Date;Duration;Routine;Exercise;Set;Warmup;Weight;Reps/Time;Goal;Perception
//
//  Puro e testabile. `Reps/Time` è duale: intero → ripetizioni, `mm:ss` →
//  durata (esercizi a tempo). Le colonne si individuano per nome, non per
//  posizione, così un riordino non rompe il parse.
//
//  NB: il formato di `Date` / `Duration` di Liftin' non è documentato — qui
//  si prova una lista di formati comuni. Da validare su un export reale.
//

import Foundation

enum LiftinCSV {

    struct Row: Equatable {
        var date: Date
        var routine: String?
        var workoutDurationSeconds: Int?
        var exercise: String
        var setIndex: Int
        var isWarmup: Bool
        var weightKg: Double
        var reps: Int?
        var setDurationSeconds: Int?
        var perception: Double?
    }

    enum ParseError: LocalizedError, Equatable {
        case emptyFile
        case missingColumns([String])
        case noValidRows

        var errorDescription: String? {
            switch self {
            case .emptyFile: return "Il file è vuoto."
            case .missingColumns(let cols): return "Colonne mancanti: \(cols.joined(separator: ", "))."
            case .noValidRows: return "Nessuna riga valida nel CSV."
            }
        }
    }

    static func parse(_ text: String) throws -> [Row] {
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let headerLine = lines.first else { throw ParseError.emptyFile }

        let header = splitRow(headerLine).map { normalizeKey($0) }
        func col(_ names: String...) -> Int? {
            for n in names { if let i = header.firstIndex(of: normalizeKey(n)) { return i } }
            return nil
        }
        let iDate = col("date")
        let iExercise = col("exercise")
        let iSet = col("set")
        guard let iDate, let iExercise, let iSet else {
            var missing: [String] = []
            if iDate == nil { missing.append("Date") }
            if iExercise == nil { missing.append("Exercise") }
            if iSet == nil { missing.append("Set") }
            throw ParseError.missingColumns(missing)
        }
        let iDuration = col("duration")
        let iRoutine = col("routine")
        let iWarmup = col("warmup")
        let iWeight = col("weight")
        let iRepsTime = col("reps/time", "repstime", "reps", "reps time")
        let iPerception = col("perception", "rpe")

        var rows: [Row] = []
        for line in lines.dropFirst() {
            let f = splitRow(line)
            func field(_ i: Int?) -> String { guard let i, i < f.count else { return "" }; return f[i] }

            guard let date = parseDate(field(iDate)) else { continue }
            let exercise = field(iExercise).trimmingCharacters(in: .whitespaces)
            guard !exercise.isEmpty else { continue }
            let setIndex = Int(field(iSet).trimmingCharacters(in: .whitespaces)) ?? 1

            let (reps, setDur) = parseRepsOrTime(field(iRepsTime))
            rows.append(Row(
                date: date,
                routine: nonEmpty(field(iRoutine)),
                workoutDurationSeconds: parseDuration(field(iDuration)),
                exercise: exercise,
                setIndex: setIndex,
                isWarmup: parseBool(field(iWarmup)),
                weightKg: parseDecimal(field(iWeight)) ?? 0,
                reps: reps,
                setDurationSeconds: setDur,
                perception: parseDecimal(field(iPerception))
            ))
        }
        guard !rows.isEmpty else { throw ParseError.noValidRows }
        return rows
    }

    // MARK: - field parsing

    private static func splitRow(_ line: String) -> [String] {
        // niente `;` dentro campi quotati negli export Liftin'; split semplice
        // + rimozione di eventuali virgolette di contorno.
        line.split(separator: ";", omittingEmptySubsequences: false).map {
            var s = $0.trimmingCharacters(in: .whitespaces)
            if s.count >= 2, s.hasPrefix("\""), s.hasSuffix("\"") {
                s = String(s.dropFirst().dropLast())
            }
            return s
        }
    }

    private static func normalizeKey(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private static func nonEmpty(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? nil : t
    }

    private static func parseBool(_ s: String) -> Bool {
        ["1", "true", "yes", "y", "si", "sì", "x", "warmup"].contains(s.lowercased())
    }

    private static func parseDecimal(_ s: String) -> Double? {
        let t = s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return t.isEmpty ? nil : Double(t)
    }

    /// Intero → reps; qualcosa con `:` → durata `mm:ss` (o `hh:mm:ss`).
    private static func parseRepsOrTime(_ s: String) -> (reps: Int?, seconds: Int?) {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return (nil, nil) }
        if t.contains(":") {
            return (nil, parseClock(t))
        }
        if let n = Int(t) { return (n, nil) }
        if let d = parseDecimal(t) { return (Int(d.rounded()), nil) }
        return (nil, nil)
    }

    /// `ss` | `mm:ss` | `hh:mm:ss` → secondi.
    private static func parseClock(_ s: String) -> Int? {
        let parts = s.split(separator: ":").map { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.allSatisfy({ $0 != nil }) else { return nil }
        let n = parts.compactMap { $0 }
        switch n.count {
        case 1: return n[0]
        case 2: return n[0] * 60 + n[1]
        case 3: return n[0] * 3600 + n[1] * 60 + n[2]
        default: return nil
        }
    }

    /// `Duration` del workout: intero di secondi, `mm:ss`/`hh:mm:ss`, o
    /// `"1h 23m"` / `"45 min"`.
    private static func parseDuration(_ s: String) -> Int? {
        let t = s.trimmingCharacters(in: .whitespaces).lowercased()
        guard !t.isEmpty else { return nil }
        if t.contains(":") { return parseClock(t) }
        if let n = Int(t) { return n }
        var total = 0, matched = false
        if let h = firstNumber(before: "h", in: t) { total += h * 3600; matched = true }
        if let m = firstNumber(before: "m", in: t) { total += m * 60; matched = true }
        if let sec = firstNumber(before: "s", in: t) { total += sec; matched = true }
        return matched ? total : nil
    }

    private static func firstNumber(before unit: Character, in s: String) -> Int? {
        guard let idx = s.firstIndex(of: unit) else { return nil }
        var digits = ""
        var i = s.index(before: idx)
        while true {
            let c = s[i]
            if c.isNumber { digits.insert(c, at: digits.startIndex) }
            else if c != " " { break }
            if i == s.startIndex { break }
            i = s.index(before: i)
        }
        return Int(digits)
    }

    private static let dateFormats = [
        "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd",
        "dd/MM/yyyy HH:mm", "dd/MM/yyyy", "MM/dd/yyyy HH:mm", "MM/dd/yyyy",
        "dd.MM.yyyy", "dd-MM-yyyy",
    ]

    private static func parseDate(_ s: String) -> Date? {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        if let d = ISO8601DateFormatter().date(from: t) { return d }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.calendar = Calendar(identifier: .gregorian)
        for f in dateFormats {
            fmt.dateFormat = f
            if let d = fmt.date(from: t) { return d }
        }
        return nil
    }
}
