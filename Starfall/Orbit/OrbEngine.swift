import Foundation

/// Physics for the orb field. Pure Swift, no UI.
/// World units: 1 ≈ the shorter usable screen side, origin at the screen centre.
/// Ported 1:1 from the Orbit web prototype so the feel (molasses drag, personal space, colour bands) matches.

func orbSmooth(_ a: Double, _ b: Double, _ x: Double) -> Double {
    let t = min(1, max(0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)
}

final class Orb {
    let id: UUID
    let soul: Soul
    let anchor: Bool
    var alive = true
    var x: Double
    var y: Double
    var vx = 0.0, vy = 0.0
    var r = 0.0, rv = 0.0
    var tr: Double
    var m = 1.0, fx = 0.0, fy = 0.0
    let seed: Double
    var grab: SIMD2<Double>?
    var pin: SIMD2<Double>?
    /// When set, every energy band slides out in this direction (Profile).
    var forceBand: SIMD2<Double>?
    /// 0…1 weight per energy, indexed like `Element.allCases`.
    let prof: [Double]
    /// 0…1 how much light the soul spends on interests: how strongly its colours take hold.
    let hold: Double
    /// 0…1 how far each energy band is slid out.
    var rev = [Double](repeating: 0, count: 5)
    /// Direction each energy band points.
    var bd: [SIMD2<Double>]
    var svx = 0.0, svy = 0.0

    init(soul: Soul, r: Double, anchor: Bool, at p: SIMD2<Double>) {
        id = soul.id
        self.soul = soul
        self.anchor = anchor
        x = p.x; y = p.y; tr = r
        seed = Double.random(in: 0..<100)
        let el = soul.elements
        prof = Element.allCases.map { e in
            let w = el[e] ?? 0
            return w > 0.04 ? w : 0
        }
        hold = soul.hold
        bd = (0..<5).map { k in
            let a = Double(k) * 1.26 - 1.57
            return SIMD2(cos(a), sin(a))
        }
    }

    func has(_ c: Int) -> Bool { prof[c] > 0 }
    /// How wide this energy's band gets when fully revealed, 0…1.
    func amount(_ c: Int) -> Double { min(1, prof[c] * 2.5) * (0.45 + 0.55 * hold) }
}

final class OrbPair {
    let a: Orb
    let b: Orb
    /// 0…1, drives attraction and rest distance.
    let sim: Double
    /// Per energy, how much both souls hold (drives the shimmer colour).
    let shared: [Double]
    var e = 0.0
    let seed: Double
    var touched = false

    init(a: Orb, b: Orb, sim: Double, shared: [Double], e: Double, seed: Double) {
        self.a = a; self.b = b; self.sim = sim; self.shared = shared; self.e = e; self.seed = seed
    }
}

struct OrbBead {
    var x: Double, y: Double, intensity: Double, seed: Double
    var tx: Double, ty: Double
    var color: SIMD3<Float>
}

final class OrbEngine {
    typealias Likeness = (Soul, Soul) -> (sim: Double, shared: [Double])

    private let like: Likeness
    private(set) var orbs: [Orb] = []
    private(set) var pairs: [OrbPair] = []
    var t = 0.0
    var rect = (l: -1.0, t: -1.0, r: 1.0, b: 1.0)
    var cx = 0.0, cy = 0.0
    var wander = 0.012
    var gather = 0.05
    /// Called once when an anchored orb (you) first truly touches another.
    var onTouch: ((OrbPair) -> Void)?

    init(like: @escaping Likeness) { self.like = like }

    func get(_ id: UUID) -> Orb? { orbs.first { $0.id == id } }

    @discardableResult
    func add(_ soul: Soul, r: Double, anchor: Bool = false, at: SIMD2<Double>? = nil) -> Orb {
        if let o = get(soul.id) { o.alive = true; o.tr = r; return o }
        let a = Double.random(in: 0..<(2 * .pi))
        let p0 = at ?? (anchor ? SIMD2(cx, cy) : SIMD2(cx + cos(a) * 0.9, cy + sin(a) * 0.9))
        let o = Orb(soul: soul, r: r, anchor: anchor, at: p0)
        orbs.append(o)
        rebuild()
        return o
    }

    /// Swap the soul behind an orb (after editing your light) without a jump.
    func replace(_ id: UUID, with soul: Soul) {
        guard let i = orbs.firstIndex(where: { $0.id == id }) else { return }
        let old = orbs[i]
        let o = Orb(soul: soul, r: old.tr, anchor: old.anchor, at: SIMD2(old.x, old.y))
        o.r = old.r; o.pin = old.pin; o.forceBand = old.forceBand; o.rev = old.rev; o.bd = old.bd
        orbs[i] = o
        rebuild()
    }

    func remove(_ id: UUID) {
        guard let o = get(id), !o.anchor else { return }
        o.alive = false; o.tr = 0; o.grab = nil
    }

    func rebuild() {
        var old: [String: Double] = [:]
        for p in pairs { old[p.a.id.uuidString + p.b.id.uuidString] = p.e }
        pairs = []
        for i in orbs.indices {
            for j in orbs.indices where j > i {
                let a = orbs[i], b = orbs[j]
                let l = like(a.soul, b.soul)
                let seed = (Double(i) * 7.13 + Double(j) * 3.71).truncatingRemainder(dividingBy: 10)
                pairs.append(OrbPair(a: a, b: b, sim: l.sim, shared: l.shared,
                                     e: old[a.id.uuidString + b.id.uuidString] ?? 0, seed: seed))
            }
        }
    }

    func hit(_ x: Double, _ y: Double) -> Orb? {
        var best: Orb?
        var bd = Double.greatestFiniteMagnitude
        for o in orbs where o.alive && o.r > 0.01 {
            let d = hypot(x - o.x, y - o.y)
            if d < o.r * 1.1 && d / o.r < bd { bd = d / o.r; best = o }
        }
        return best
    }

    func step(_ dt: Double) {
        t += dt
        let n = max(1, Int((dt / (1.0 / 120)).rounded(.up)))
        let h = dt / Double(n)
        for _ in 0..<n { sub(h) }
        bands(dt)
        let before = orbs.count
        orbs.removeAll { !$0.alive && $0.r <= 0.003 }
        if orbs.count != before { rebuild() }
    }

    /// Colour reveal: a band slides out when the orb moves fast, or when a neighbour that shares
    /// that energy comes close. It points toward those neighbours, or trails behind the motion.
    private func bands(_ dt: Double) {
        for o in orbs {
            let kv = 1 - exp(-dt * 5)
            o.svx += (o.vx - o.svx) * kv
            o.svy += (o.vy - o.svy) * kv
            let sp = hypot(o.svx, o.svy)
            let motion = o.pin != nil ? 0 : orbSmooth(0.04, 0.32, sp)
            for c in 0..<5 {
                var aff = 0.0, ax = 0.0, ay = 0.0
                if o.has(c) {
                    for j in orbs where j !== o && j.alive && j.has(c) {
                        let dx = j.x - o.x, dy = j.y - o.y
                        let d = max(1e-4, hypot(dx, dy)), sum = o.r + j.r
                        let a = orbSmooth(sum * 2.3, sum * 1.02, d) * min(1, j.prof[c] * 3)
                        aff += a; ax += a * dx / d; ay += a * dy / d
                    }
                }
                var target = o.has(c) && o.alive ? min(1, motion + aff * 1.3) : 0
                var tx = ax, ty = ay
                if sp > 1e-4 && motion > 0 { tx -= (o.svx / sp) * motion * 0.9; ty -= (o.svy / sp) * motion * 0.9 }
                if let f = o.forceBand, o.has(c) { target = 1; tx = f.x; ty = f.y }
                let rate = target > o.rev[c] ? 2.4 : 0.9
                o.rev[c] += (target - o.rev[c]) * (1 - exp(-dt * rate))
                let tl = hypot(tx, ty)
                if tl > 1e-3 {
                    let k = 1 - exp(-dt * 3)
                    var b = o.bd[c]
                    b.x += (tx / tl - b.x) * k
                    b.y += (ty / tl - b.y) * k
                    let bl = max(1e-6, hypot(b.x, b.y))
                    o.bd[c] = SIMD2(b.x / bl, b.y / bl)
                }
            }
        }
    }

    private func sub(_ h: Double) {
        let R = rect
        for o in orbs {
            o.rv += ((o.tr - o.r) * 90 - o.rv * 13) * h
            o.r = max(0, o.r + o.rv * h)
            let base = max(o.tr, o.r, 0.05)
            o.m = max(0.35, pow(base / 0.12, 2))
            o.fx = 0; o.fy = 0
            if let p = o.pin {
                o.fx += (p.x - o.x) * 26 * o.m
                o.fy += (p.y - o.y) * 26 * o.m
                continue
            }
            let kc = o.anchor ? 1.6 : gather
            o.fx += (cx - o.x) * kc * o.m
            o.fy += (cy - o.y) * kc * o.m
            o.fx += sin(t * 0.37 + o.seed) * wander * o.m
            o.fy += cos(t * 0.29 + o.seed * 1.3) * wander * o.m
            let l = R.l + o.r * 0.9, rg = R.r - o.r * 0.9, tp = R.t + o.r * 0.9, bt = R.b - o.r * 0.9
            if o.x < l { o.fx += (l - o.x) * 10 * o.m }
            if o.x > rg { o.fx -= (o.x - rg) * 10 * o.m }
            if o.y < tp { o.fy += (tp - o.y) * 10 * o.m }
            if o.y > bt { o.fy -= (o.y - bt) * 10 * o.m }
            if let g = o.grab {
                o.fx += (g.x - o.x) * 16 * o.m
                o.fy += (g.y - o.y) * 16 * o.m
            }
        }
        for p in pairs {
            let a = p.a, b = p.b
            let dx = b.x - a.x, dy = b.y - a.y
            let d = max(1e-4, hypot(dx, dy)), ux = dx / d, uy = dy / d
            let sum = a.r + b.r
            if sum < 1e-3 { continue }
            let sim = a.alive && b.alive ? p.sim : 0
            let close = orbSmooth(sum * 2.0, sum * 0.98, d)
            p.e += (sim * close - p.e) * (1 - exp(-h * 2.2))
            if (a.anchor || b.anchor) {
                if !p.touched && p.e > 0.35 { p.touched = true; onTouch?(p) }
                if p.touched && p.e < 0.12 { p.touched = false }
            }
            if a.pin != nil || b.pin != nil { continue } // pinned orbs sit where they are told
            let rest = sum * (1.9 - 0.82 * sim), range = sum * 3.4
            var f = 0.0
            if d < range {
                let g = d - rest
                f = max(-sum, min(sum, g)) * (g > 0 ? 0.3 + 1.1 * sim : 1.6)
            }
            let core = sum * 0.8 // personal space: you are still yourself
            if d < core { f -= (core - d) * ((a.grab != nil || b.grab != nil) ? 30 : 16) }
            f *= min(a.m, b.m)
            a.fx += ux * f; a.fy += uy * f
            b.fx -= ux * f; b.fy -= uy * f
            if d < sum * 1.35 { // viscosity: touching orbs drag each other along
                let k = min(1, 2.2 * h) * 0.5
                let rx = (b.vx - a.vx) * k, ry = (b.vy - a.vy) * k
                a.vx += rx; a.vy += ry; b.vx -= rx; b.vy -= ry
            }
        }
        for o in orbs {
            let drag = exp(-h * (o.pin != nil ? 9 : o.grab != nil ? 7 : 3.4))
            o.vx = (o.vx + (o.fx / o.m) * h) * drag
            o.vy = (o.vy + (o.fy / o.m) * h) * drag
            let sp = hypot(o.vx, o.vy), mx = (o.grab != nil || o.pin != nil) ? 3.0 : 0.55
            if sp > mx { o.vx *= mx / sp; o.vy *= mx / sp }
            o.x += o.vx * h
            o.y += o.vy * h
        }
    }

    /// Diamond-ring shimmer where similar rims cross, or a glint where they nearly touch.
    func beads(palette: [SIMD3<Float>]) -> [OrbBead] {
        var out: [OrbBead] = []
        for p in pairs where p.e >= 0.03 && p.a.pin == nil && p.b.pin == nil {
            let a = p.a, b = p.b, ri = a.r, rj = b.r
            let dx = b.x - a.x, dy = b.y - a.y
            let d = max(1e-4, hypot(dx, dy)), ux = dx / d, uy = dy / d, sum = ri + rj
            let tot = max(1e-6, p.shared.reduce(0, +))
            var col = SIMD3<Float>(1, 0.9, 0.75)
            if tot > 1e-5 {
                col = .zero
                for k in 0..<5 { col += palette[k] * Float(p.shared[k] / tot) }
            }
            if d < sum && d > abs(ri - rj) + 1e-4 {
                let aa = (ri * ri - rj * rj + d * d) / (2 * d)
                let hh = sqrt(max(0, ri * ri - aa * aa))
                let mx = a.x + ux * aa, my = a.y + uy * aa, depth = (sum - d) / sum
                for sg in [1.0, -1.0] {
                    let px = mx - uy * hh * sg, py = my + ux * hh * sg
                    let tix = -(py - a.y) / ri, tiy = (px - a.x) / ri
                    var tjx = -(py - b.y) / rj, tjy = (px - b.x) / rj
                    if tix * tjx + tiy * tjy < 0 { tjx = -tjx; tjy = -tjy }
                    var tx = tix + tjx, ty = tiy + tjy
                    let tl = max(1e-6, hypot(tx, ty)); tx /= tl; ty /= tl
                    out.append(OrbBead(x: px, y: py, intensity: min(0.85, p.e * (0.5 + depth * 1.8)),
                                       seed: p.seed + (sg > 0 ? 0 : 5), tx: tx, ty: ty, color: col))
                }
            } else if d >= sum && d < sum * 1.3 {
                let k = 1 - (d - sum) / (0.3 * sum), r0 = ri + (d - sum) / 2
                out.append(OrbBead(x: a.x + ux * r0, y: a.y + uy * r0, intensity: p.e * 0.4 * k,
                                   seed: p.seed, tx: -uy, ty: ux, color: col))
            }
        }
        return Array(out.sorted { $0.intensity > $1.intensity }.prefix(8))
    }

    /// One global stacking order for the energy layers so bands nest (front = closest to the body).
    func layerOrder() -> [Int] {
        var tot = [Double](repeating: 0, count: 5)
        for o in orbs { for k in 0..<5 { tot[k] += o.prof[k] * (0.3 + o.rev[k]) } }
        return (0..<5).sorted { tot[$0] > tot[$1] }
    }
}
