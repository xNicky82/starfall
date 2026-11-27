import XCTest
@testable import Starfall

final class BankTests: XCTestCase {
    func testBankIsFinite() {
        var s = Soul(name: "t")
        s.setInterest("hiking", 20)
        s.setInterest("music", 20)
        s.setValue("truth", 40)
        s.setValue("beauty", 40) // only 20 left
        XCTAssertEqual(s.valueWeight("beauty"), 20)
        XCTAssertEqual(s.remaining, 0)
        s.setInterest("film", 10)
        XCTAssertEqual(s.interestWeight("film"), 0, "no light left")
    }

    func testInterestCeiling() {
        var s = Soul(name: "t")
        s.setInterest("hiking", 50)
        XCTAssertEqual(s.interestWeight("hiking"), Soul.interestCeiling)
        XCTAssertTrue(s.canAscend("hiking"))
    }

    func testAscensionMovesLightIntoValue() {
        var s = Soul(name: "t")
        s.setInterest("hiking", 20)
        let before = s.effectiveValue("presence")
        XCTAssertEqual(before, 20 * Soul.undercurrent, accuracy: 0.001)
        s.ascend("hiking")
        XCTAssertEqual(s.effectiveValue("presence"), 20, accuracy: 0.001)
        XCTAssertTrue(s.activeInterests.isEmpty)
        XCTAssertEqual(s.spent, 20, "ascending doesn't create or destroy light")
        s.descend("hiking")
        XCTAssertFalse(s.ascended.contains("hiking"))
    }

    func testResonanceSymmetryAndRange() {
        let field = SoulFactory.field()
        for a in field.prefix(6) {
            for b in field.prefix(6) {
                let r1 = Resonance.between(a, b), r2 = Resonance.between(b, a)
                XCTAssertEqual(r1.score, r2.score, accuracy: 1e-9)
                XCTAssert((0...1).contains(r1.score))
            }
            XCTAssertEqual(Resonance.between(a, a).meeting, .mend)
        }
    }

    func testFieldHasAllMeetings() {
        let field = SoulFactory.field()
        var me = Soul(name: "me")
        me.setInterest("hiking", 20); me.ascend("hiking")
        me.setInterest("music", 14); me.setInterest("hardware", 12); me.setInterest("sauna", 10)
        me.setValue("wonder", 20); me.setValue("kindness", 12)
        var counts: [Meeting: Int] = [:]
        for o in field { counts[Resonance.between(me, o).meeting, default: 0] += 1 }
        print("meeting distribution:", counts)
        for o in field { let r = Resonance.between(me, o); print(String(format: "SCORE %.2f v%.2f i%.2f t%.2f", r.score, r.values, r.interests, r.traits)) }
        var all: [Double] = []; for a in field { for b in field where a.id != b.id { all.append(Resonance.between(a, b).score) } }
        all.sort(); print("PCT", all[all.count/4], all[all.count/2], all[all.count*3/4], all[all.count*9/10])
        XCTAssertEqual(counts.values.reduce(0, +), field.count)
    }

    func testFieldIsDeterministic() {
        XCTAssertEqual(SoulFactory.field().map(\.id), SoulFactory.field().map(\.id))
    }

    func testScoreEncoding() {
        let d = VibrationScore.mend.encoded()
        XCTAssertEqual(Int(d[0]), VibrationScore.mend.beats.count)
        XCTAssertEqual(d.count, 1 + 6 * VibrationScore.mend.beats.count)
    }
}
