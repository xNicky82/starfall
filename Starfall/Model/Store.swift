import SwiftUI
import Observation

struct BondRecord: Codable, Identifiable, Hashable {
    enum Choice: String, Codable { case bonded, released }
    var id = UUID()
    var soulID: UUID
    var choice: Choice
    var meeting: Meeting
    var score: Double
    var date = Date()
}

@Observable
final class Store {
    var me: Soul? { didSet { save() } }
    var bonds: [BondRecord] = [] { didSet { save() } }
    let others: [Soul] = SoulFactory.field()
    /// Transient: hides navigation while two souls are meeting.
    var inEncounter = false

    private struct Saved: Codable { var me: Soul?; var bonds: [BondRecord] }
    private let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("starfall.json")

    init() {
        if let data = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(Saved.self, from: data) {
            me = s.me; bonds = s.bonds
        }
    }

    private func save() {
        let s = Saved(me: me, bonds: bonds)
        if let data = try? JSONEncoder().encode(s) { try? data.write(to: url, options: .atomic) }
    }

    func soul(_ id: UUID) -> Soul? { others.first { $0.id == id } }

    func record(_ soul: Soul, choice: BondRecord.Choice, resonance: Resonance) {
        bonds.removeAll { $0.soulID == soul.id }
        bonds.append(BondRecord(soulID: soul.id, choice: choice, meeting: resonance.meeting, score: resonance.score))
    }
    var bonded: [BondRecord] { bonds.filter { $0.choice == .bonded }.sorted { $0.date > $1.date } }

    func reset() { me = nil; bonds = [] }
}
