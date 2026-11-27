import SwiftUI
import simd

/// Every soul is a Lorenz system. Its parameters come from who they are.
struct LorenzParams: Hashable {
    var sigma = 10.0
    var rho = 28.0
    var beta = 8.0 / 3.0
    var yaw = 0.0     // view rotation about z
    var pitch = 0.0   // view tilt

    static let classic = LorenzParams()

    func f(_ p: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(sigma * (p.y - p.x), p.x * (rho - p.z) - p.y, p.x * p.y - beta * p.z)
    }
}

enum Lorenz {
    static func rk4(_ p: SIMD3<Double>, _ dt: Double, _ f: (SIMD3<Double>) -> SIMD3<Double>) -> SIMD3<Double> {
        let k1 = f(p), k2 = f(p + 0.5 * dt * k1), k3 = f(p + 0.5 * dt * k2), k4 = f(p + dt * k3)
        return p + dt / 6 * (k1 + 2 * k2 + 2 * k3 + k4)
    }

    /// A trajectory on the attractor (transient discarded).
    static func trajectory(_ q: LorenzParams, steps: Int = 5000, dt: Double = 0.006,
                           start: SIMD3<Double> = [0.1, 0, 20]) -> [SIMD3<Double>] {
        var p = start
        for _ in 0..<300 { p = rk4(p, dt, q.f) }
        var out = [SIMD3<Double>](); out.reserveCapacity(steps)
        for _ in 0..<steps { p = rk4(p, dt, q.f); out.append(p) }
        return out
    }

    /// Rotate about z by yaw, tilt by pitch, then look along y: screen = (x', z').
    static func project(_ p: SIMD3<Double>, yaw: Double, pitch: Double, zMid: Double) -> CGPoint {
        let cy = cos(yaw), sy = sin(yaw)
        let x = p.x * cy - p.y * sy, y = p.x * sy + p.y * cy
        let z = p.z - zMid
        let cp = cos(pitch), sp = sin(pitch)
        let z2 = z * cp - y * sp
        return CGPoint(x: x, y: -z2)
    }

    /// Path through the projected trajectory, fitted into `rect`.
    static func path(_ pts: [SIMD3<Double>], yaw: Double, pitch: Double, in rect: CGRect,
                     upTo n: Int? = nil, scale fixed: CGFloat? = nil) -> Path {
        guard !pts.isEmpty else { return Path() }
        let zMid = 0.5 * ((pts.map(\.z).min() ?? 0) + (pts.map(\.z).max() ?? 0))
        let proj = pts.map { project($0, yaw: yaw, pitch: pitch, zMid: zMid) }
        var minX = CGFloat.infinity, maxX = -CGFloat.infinity, minY = CGFloat.infinity, maxY = -CGFloat.infinity
        for p in proj { minX = min(minX, p.x); maxX = max(maxX, p.x); minY = min(minY, p.y); maxY = max(maxY, p.y) }
        let s = fixed ?? min(rect.width / max(1, maxX - minX), rect.height / max(1, maxY - minY))
        let cx = (minX + maxX) / 2, cy = (minY + maxY) / 2
        let count = min(n ?? proj.count, proj.count)
        var path = Path()
        for i in 0..<count {
            let q = CGPoint(x: rect.midX + (proj[i].x - cx) * s, y: rect.midY + (proj[i].y - cy) * s)
            if i == 0 { path.move(to: q) } else { path.addLine(to: q) }
        }
        return path
    }
}

extension Soul {
    /// Who you are, as an attractor.
    var lorenz: LorenzParams {
        let valueShare = values.values.reduce(0, +) / Soul.bank + Double(ascended.count) * 0.06
        let lead = Element.allCases.firstIndex(of: aura.first?.0 ?? .tide) ?? 1
        return LorenzParams(
            sigma: 10 + 3 * trait("pace"),                          // stillness ↔ motion
            rho: 25.5 + 16 * min(1, valueShare) + 3 * trait("fire"), // what you hold deepens the wings
            beta: 8.0 / 3.0 + 0.35 * trait("compass"),               // heart ↔ mind
            yaw: Double(lead) * 0.55 - 1.1 + 0.25 * trait("gaze"),
            pitch: 0.12 * trait("social"))
    }
}

/// Two souls, two Lorenz systems, coupled by resonance.
/// Strong coupling → the trajectories synchronise. Weak → each stays its own chaos.
final class CoupledLorenz {
    var a: SIMD3<Double> = [1, 1, 22]
    var b: SIMD3<Double> = [-9, -4, 31]
    let pa: LorenzParams, pb: LorenzParams
    let k: Double
    private(set) var trailA: [SIMD3<Double>] = []
    private(set) var trailB: [SIMD3<Double>] = []
    private(set) var sync = 0.0 // 0 apart … 1 together (smoothed)
    let cap = 1400

    init(_ pa: LorenzParams, _ pb: LorenzParams, k: Double) {
        self.pa = pa; self.pb = pb; self.k = k
    }

    func advance(steps: Int = 6, dt: Double = 0.0045) {
        for _ in 0..<steps {
            let s: (SIMD3<Double>, SIMD3<Double>) = (a, b)
            func f(_ x: SIMD3<Double>, _ y: SIMD3<Double>) -> (SIMD3<Double>, SIMD3<Double>) {
                (pa.f(x) + k * (y - x), pb.f(y) + k * (x - y))
            }
            let k1 = f(s.0, s.1)
            let k2 = f(s.0 + 0.5 * dt * k1.0, s.1 + 0.5 * dt * k1.1)
            let k3 = f(s.0 + 0.5 * dt * k2.0, s.1 + 0.5 * dt * k2.1)
            let k4 = f(s.0 + dt * k3.0, s.1 + dt * k3.1)
            a = s.0 + dt / 6 * (k1.0 + 2 * k2.0 + 2 * k3.0 + k4.0)
            b = s.1 + dt / 6 * (k1.1 + 2 * k2.1 + 2 * k3.1 + k4.1)
            trailA.append(a); trailB.append(b)
        }
        if trailA.count > cap { trailA.removeFirst(trailA.count - cap); trailB.removeFirst(trailB.count - cap) }
        let d = simd_length(a - b)
        sync += ((d < 4 ? 1 : max(0, 1 - (d - 4) / 20)) - sync) * 0.04
    }
}
