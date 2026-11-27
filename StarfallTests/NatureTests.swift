import XCTest
@testable import Starfall

final class NatureTests: XCTestCase {
    func testObserverIsAssumedToWatch() {
        var s = Soul(name: "Obs")
        s.toggleInterest("sport")
        s.traits["stance"] = -1
        XCTAssertEqual(s.engagement("sport").mode, .watch)
        XCTAssertTrue(s.engagement("sport").assumed)

        s.traits["stance"] = 1
        XCTAssertEqual(s.engagement("sport").mode, .play)

        s.setEngagement("sport", .both)
        XCTAssertEqual(s.engagement("sport").mode, .both)
        XCTAssertFalse(s.engagement("sport").assumed)
    }

    func testNatureSetsColours() {
        var quiet = Soul(name: "Q"), loud = Soul(name: "L")
        for p in ["social", "volume", "stance", "edge"] { quiet.traits[p] = -1; loud.traits[p] = 1 }
        XCTAssertGreaterThan(quiet.elements[.tide] ?? 0, loud.elements[.tide] ?? 0)
        XCTAssertGreaterThan(loud.elements[.ember] ?? 0, quiet.elements[.ember] ?? 0)
        XCTAssertEqual(quiet.elements.values.reduce(0, +), 1, accuracy: 1e-9)
    }

    func testInterestsDecideHowStronglyAColourHolds() {
        var a = Soul(name: "A")
        let before = a.elements[.sol] ?? 0
        a.setInterest("music", 20) // rooted in Beauty, a Sol value
        XCTAssertGreaterThan(a.elements[.sol] ?? 0, before)
    }

    func testRemovingAnInterestClearsItsSpecifics() {
        var s = Soul(name: "S")
        s.toggleInterest("sport")
        s.toggleSpecific("sport", "Hockey")
        XCTAssertEqual(s.specifics("sport"), ["Hockey"])
        s.toggleInterest("sport")
        XCTAssertTrue(s.specifics("sport").isEmpty)
    }
}
