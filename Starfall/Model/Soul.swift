import SwiftUI

/// A soul is a fixed amount of light spent across interests and values,
/// plus a position on each trait polarity.
struct Soul: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    /// interest id → light spent (0…interestCeiling)
    var interests: [String: Double] = [:]
    /// interests that were pushed past their ceiling and became part of their root value
    var ascended: Set<String> = []
    /// value id → light spent directly (0…valueCeiling)
    var values: [String: Double] = [:]
    /// trait id → position, -1 (left pole) … +1 (right pole)
    var traits: [String: Double] = [:]
    var bornAt: Date = Date()
}

// MARK: - The Bank

extension Soul {
    /// Every soul gets the same amount of light. Loving one thing costs loving another.
    static let bank: Double = 100
    /// An interest cannot hold more than this. Pushing past it turns the interest into a value.
    static let interestCeiling: Double = 20
    static let valueCeiling: Double = 40
    /// Share of a (non-ascended) interest's light that quietly feeds its root value.
    static let undercurrent: Double = 0.25

    var spent: Double { interests.values.reduce(0, +) + values.values.reduce(0, +) }
    var remaining: Double { max(0, Soul.bank - spent) }

    func interestWeight(_ id: String) -> Double { interests[id] ?? 0 }
    func valueWeight(_ id: String) -> Double { values[id] ?? 0 }

    /// The most this interest could hold right now, given what's left in the bank.
    func interestLimit(_ id: String) -> Double { min(Soul.interestCeiling, interestWeight(id) + remaining) }
    func valueLimit(_ id: String) -> Double { min(Soul.valueCeiling, valueWeight(id) + remaining) }

    mutating func setInterest(_ id: String, _ w: Double) {
        guard !ascended.contains(id) else { return }
        interests[id] = max(0, min(w, interestLimit(id)))
    }
    mutating func setValue(_ id: String, _ w: Double) {
        values[id] = max(0, min(w, valueLimit(id)))
    }
    mutating func toggleInterest(_ id: String) {
        if interests[id] != nil {
            interests[id] = nil; ascended.remove(id)
        } else {
            interests[id] = min(6, remaining)
        }
    }
    func canAscend(_ id: String) -> Bool { !ascended.contains(id) && interestWeight(id) >= Soul.interestCeiling - 0.01 }

    /// An interest loved at full strength stops being a hobby and becomes something you *are*.
    mutating func ascend(_ id: String) {
        guard interests[id] != nil else { return }
        interests[id] = Soul.interestCeiling
        ascended.insert(id)
    }
    mutating func descend(_ id: String) {
        ascended.remove(id)
        interests[id] = Soul.interestCeiling * 0.75
    }

    /// The light that flows into a value from interests rooted in it.
    func undercurrent(into valueID: String) -> Double {
        Catalog.interests(rootedIn: valueID).reduce(0) { acc, f in
            guard let w = interests[f.id] else { return acc }
            return acc + (ascended.contains(f.id) ? w : w * Soul.undercurrent)
        }
    }
    /// What a value actually weighs: what you gave it + what your interests feed it.
    func effectiveValue(_ id: String) -> Double { valueWeight(id) + undercurrent(into: id) }
    var effectiveValues: [String: Double] {
        Dictionary(uniqueKeysWithValues: Catalog.values.map { ($0.id, effectiveValue($0.id)) })
    }
    /// Interests that are still interests (not ascended).
    var activeInterests: [(Facet, Double)] {
        interests.compactMap { id, w in
            guard !ascended.contains(id), let f = Catalog.facet(id) else { return nil }
            return (f, w)
        }.sorted { $0.1 > $1.1 }
    }
    var topValues: [(Facet, Double)] {
        Catalog.values.map { ($0, effectiveValue($0.id)) }.filter { $0.1 > 0.5 }.sorted { $0.1 > $1.1 }
    }
    func trait(_ id: String) -> Double { traits[id] ?? 0 }

    // MARK: Aura

    /// How much of each element this soul is made of (sums to 1).
    var elements: [Element: Double] {
        var e: [Element: Double] = [:]
        for (id, w) in interests where !ascended.contains(id) {
            if let f = Catalog.facet(id) { e[f.element, default: 0] += w * (1 - Soul.undercurrent) }
        }
        for (id, w) in effectiveValues { if let f = Catalog.facet(id) { e[f.element, default: 0] += w } }
        let total = e.values.reduce(0, +)
        guard total > 0 else { return [.tide: 1] }
        return e.mapValues { $0 / total }
    }
    /// Dominant energies, strongest first.
    var aura: [(Element, Double)] { elements.sorted { $0.value > $1.value }.filter { $0.value > 0.04 } }
    var auraColors: [Color] {
        let a = aura.prefix(3).map { $0.0.color }
        return a.isEmpty ? [SF.blue] : a
    }
    /// A single blended colour — the soul's "frequency".
    var hue: Color {
        var c = SIMD3<Double>(0, 0, 0)
        for (el, w) in elements { c += el.rgb * w }
        return Color(red: c.x, green: c.y, blue: c.z)
    }
    var isAttuned: Bool { !interests.isEmpty && spent > 0 }
}
