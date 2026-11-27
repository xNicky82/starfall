import Foundation

/// The three ways two souls can meet.
enum Meeting: String, Codable, CaseIterable {
    /// Energies flow together.
    case mend
    /// Same values, different weather — friction that can light something.
    case spark
    /// Energies push apart.
    case clash

    var word: String { rawValue.uppercased() }
    var line: String {
        switch self {
        case .mend:  return "Your energies flow into each other."
        case .spark: return "Shared ground, different weather."
        case .clash: return "Your energies push apart."
        }
    }
}

struct Resonance: Hashable {
    var score: Double        // 0…1
    var values: Double       // 0…1 alignment of what you hold
    var interests: Double    // 0…1 overlap of what you do
    var traits: Double       // 0…1 harmony of how you are
    var meeting: Meeting
    var sharedValues: [String]
    var sharedInterests: [String]

    static let weights = (values: 0.5, interests: 0.3, traits: 0.2)

    static func between(_ a: Soul, _ b: Soul) -> Resonance {
        // Values: cosine similarity of effective value vectors.
        let ids = Catalog.values.map(\.id)
        let va = ids.map { a.effectiveValue($0) }, vb = ids.map { b.effectiveValue($0) }
        let dot = zip(va, vb).reduce(0) { $0 + $1.0 * $1.1 }
        let na = sqrt(va.reduce(0) { $0 + $1 * $1 }), nb = sqrt(vb.reduce(0) { $0 + $1 * $1 })
        let values = (na > 0 && nb > 0) ? dot / (na * nb) : 0.5

        // Interests: light both souls spend on the same things, relative to the smaller bank of interests.
        var shared = 0.0
        var sharedInterests: [(String, Double)] = []
        for (id, wa) in a.interests {
            if let wb = b.interests[id] { shared += min(wa, wb); sharedInterests.append((id, wa + wb)) }
        }
        let ia = a.interests.values.reduce(0, +), ib = b.interests.values.reduce(0, +)
        let interests = min(1, shared / max(1, min(ia, ib)))

        // Traits: harmonic axes mend when close; complementary axes mend with a little distance.
        var t = 0.0
        for p in Catalog.traits {
            let d = abs(a.trait(p.id) - b.trait(p.id)) / 2 // 0…1
            if p.harmonic {
                t += 1 - d
            } else {
                // best at ~0.3 apart, worst at full opposition
                t += max(0, 1 - abs(d - 0.3) / 0.7)
            }
        }
        let traits = t / Double(Catalog.traits.count)

        let w = weights
        let score = w.values * values + w.interests * interests + w.traits * traits

        let meeting: Meeting
        // Calibrated against the demo field: roughly top fifth mend, bottom third clash.
        if score >= 0.45 { meeting = .mend }
        else if score >= 0.27 || (values >= 0.5 && traits < 0.6) { meeting = .spark }
        else { meeting = .clash }

        let sharedValues = ids
            .map { ($0, min(a.effectiveValue($0), b.effectiveValue($0))) }
            .filter { $0.1 > 2 }
            .sorted { $0.1 > $1.1 }
            .map(\.0)

        return Resonance(score: score, values: values, interests: interests, traits: traits,
                         meeting: meeting, sharedValues: sharedValues,
                         sharedInterests: sharedInterests.sorted { $0.1 > $1.1 }.map(\.0))
    }
}
