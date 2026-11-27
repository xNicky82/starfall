import XCTest
import SwiftUI
@testable import Starfall

final class LorenzTests: XCTestCase {
    func testTrajectoryIsChaoticAndFinite() {
        let pts = Lorenz.trajectory(.classic, steps: 3000)
        XCTAssertEqual(pts.count, 3000)
        XCTAssert(pts.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
        let xs = pts.map(\.x)
        print("LORENZ x range", xs.min()!, xs.max()!)
        XCTAssert(xs.min()! < -10 && xs.max()! > 10, "should visit both wings")
    }

    func testPathFitsRect() {
        let pts = Lorenz.trajectory(.classic, steps: 3000)
        let rect = CGRect(x: 0, y: 0, width: 300, height: 330)
        let p = Lorenz.path(pts, yaw: 0, pitch: 0, in: rect)
        print("LORENZ path bounds", p.boundingRect)
        XCTAssert(p.boundingRect.width > 200)
    }

    func testCoupledMendSynchronises() {
        let sys = CoupledLorenz(.classic, .classic, k: 6)
        for _ in 0..<400 { sys.advance() }
        print("LORENZ sync", sys.sync, sys.a, sys.b)
        XCTAssertGreaterThan(sys.sync, 0.8)
        let loose = CoupledLorenz(.classic, LorenzParams(sigma: 12, rho: 34, beta: 2.4), k: 0)
        for _ in 0..<400 { loose.advance() }
        print("LORENZ loose", loose.sync, loose.a, loose.b)
        let xs = loose.trailA.map(\.x)
        XCTAssert(xs.min()! < -5 && xs.max()! > 5)
    }

    func testSoulsAreChaotic() {
        for s in SoulFactory.field() {
            let q = s.lorenz
            let pts = Lorenz.trajectory(q, steps: 4000)
            let xs = pts.suffix(2000).map(\.x)
            XCTAssert(xs.min()! < -3 && xs.max()! > 3, "\(s.name) collapsed to a fixed point: \(q)")
        }
    }
}
