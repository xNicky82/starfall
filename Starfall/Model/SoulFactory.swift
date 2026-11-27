import Foundation

/// Deterministic RNG so the demo field is the same every launch.
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Generates the other drifting souls until real people (and devices) exist.
enum SoulFactory {
    static let names = ["Ines", "Theo", "Mara", "Kai", "Noor", "Elio", "Saoirse", "Jun", "Amara",
                        "Lev", "Iris", "Rumi", "Odile", "Sami", "Wren", "Ezra", "Lumi", "Ari",
                        "Nadia", "Cass", "Yara", "Felix", "Juno", "Mika"]

    static func field(count: Int = 22, seed: UInt64 = 0x5747_4146_414C_4C) -> [Soul] {
        var rng = SplitMix64(seed: seed)
        return (0..<count).map { i in make(name: names[i % names.count], rng: &rng) }
    }

    static func make(name: String, rng: inout SplitMix64) -> Soul {
        var s = Soul(name: name)
        // Stable ids so bonds survive relaunches.
        let a = rng.next(), b = rng.next()
        let bytes = withUnsafeBytes(of: (a, b)) { Array($0) }
        s.id = UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
        // Each soul leans toward one or two elements, which shapes what they choose.
        let lean = Element.allCases.shuffled(using: &rng).prefix(2)
        let pool = Catalog.interests.filter { lean.contains($0.element) } + Catalog.interests.shuffled(using: &rng).prefix(6)
        for f in pool.shuffled(using: &rng).prefix(Int.random(in: 3...6, using: &rng)) where s.interests[f.id] == nil {
            s.setInterest(f.id, Double(Int.random(in: 4...20, using: &rng)))
            if s.canAscend(f.id) && Bool.random(using: &rng) { s.ascend(f.id) }
        }
        let vpool = Catalog.values.filter { lean.contains($0.element) } + Catalog.values.shuffled(using: &rng).prefix(2)
        for f in vpool.shuffled(using: &rng).prefix(Int.random(in: 2...4, using: &rng)) {
            s.setValue(f.id, s.valueWeight(f.id) + Double(Int.random(in: 6...24, using: &rng)))
        }
        for p in Catalog.traits {
            s.traits[p.id] = (Double.random(in: -1...1, using: &rng) * 4).rounded() / 4
        }
        // One or two specifics inside each interest, plus a stated watch/play now and then.
        for id in s.interests.keys.sorted() {
            if let opts = Catalog.specifics[id] {
                for n in opts.shuffled(using: &rng).prefix(Int.random(in: 1...2, using: &rng)) { s.toggleSpecific(id, n) }
            }
            if Catalog.engagement[id] != nil, Int.random(in: 0..<3, using: &rng) == 0 {
                s.setEngagement(id, Engagement.allCases.randomElement(using: &rng))
            }
        }
        return s
    }
}
