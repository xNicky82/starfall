import SwiftUI

/// The field: every other soul is an attractor; you are a trajectory moving between them.
final class FieldSim {
    struct Attractor {
        let soul: Soul
        let res: Resonance
        let home: CGPoint
        var p: CGPoint
        let strength: Double   // how hard they pull on you (0…1)
        let spin: Double       // ±1 — which way you orbit them
        let phase: Double
        var met: Bool
        var core: CGFloat { 9 + 9 * CGFloat(strength) }
    }

    var attractors: [Attractor] = []
    var x: CGPoint = .zero
    var v: CGVector = .zero
    var trail: [CGPoint] = []
    var size: CGSize = .zero
    var touch: CGPoint? = nil
    var paused = false
    var nearest: (index: Int, edge: CGFloat)?
    private var last: Double?
    private var nextPulse = 0.0
    private var grace = 0.0
    var onCollide: ((Soul, Resonance) -> Void)?

    static let feel: CGFloat = 110

    func configure(me: Soul, others: [Soul], met: Set<UUID>, size: CGSize) {
        self.size = size
        var rng = SplitMix64(seed: 11)
        var placed: [CGPoint] = []
        attractors = others.map { o in
            var p = CGPoint.zero
            for _ in 0..<60 {
                p = CGPoint(x: .random(in: 40...(size.width - 40), using: &rng),
                            y: .random(in: 110...(size.height - 150), using: &rng))
                if placed.allSatisfy({ hypot($0.x - p.x, $0.y - p.y) > 58 }) { break }
            }
            placed.append(p)
            let r = Resonance.between(me, o)
            return Attractor(soul: o, res: r, home: p, p: p,
                             strength: min(1, max(0.06, (r.score - 0.12) / 0.5)),
                             spin: Bool.random(using: &rng) ? 1 : -1,
                             phase: .random(in: 0...10, using: &rng), met: met.contains(o.id))
        }
        x = CGPoint(x: size.width / 2, y: size.height * 0.52)
        v = CGVector(dx: 40, dy: -20)
        trail = []
        last = nil
        grace = 2
    }

    func markMet(_ id: UUID) {
        guard let i = attractors.firstIndex(where: { $0.soul.id == id }) else { return }
        attractors[i].met = true
        let d = CGVector(dx: x.x - attractors[i].p.x, dy: x.y - attractors[i].p.y)
        let n = max(1, hypot(d.dx, d.dy))
        v = CGVector(dx: d.dx / n * 120, dy: d.dy / n * 120)
        grace = 1.5
    }

    /// Acceleration the field exerts at point q.
    func field(at q: CGPoint) -> CGVector {
        var a = CGVector.zero
        for m in attractors where !m.met {
            let dx = m.p.x - q.x, dy = m.p.y - q.y
            let r = max(6, hypot(dx, dy))
            let g = 420 * m.strength / pow(1 + r / 70, 2)
            a.dx += (dx / r) * g + m.spin * (-dy / r) * g * 0.9
            a.dy += (dy / r) * g + m.spin * (dx / r) * g * 0.9
        }
        return a
    }

    func step(t: Double) {
        guard let l = last else { last = t; return }
        last = t
        guard !paused, size.width > 0 else { return }
        let dt = min(1.0 / 30, t - l)
        grace = max(0, grace - dt)

        for i in attractors.indices {
            let m = attractors[i]
            attractors[i].p = CGPoint(x: m.home.x + 14 * CGFloat(sin(t * 0.13 + m.phase)),
                                      y: m.home.y + 14 * CGFloat(cos(t * 0.11 + m.phase * 1.7)))
        }

        var a = field(at: x)
        if let f = touch {
            a.dx += (f.x - x.x) * 7 - v.dx * 2.2
            a.dy += (f.y - x.y) * 7 - v.dy * 2.2
        }
        a.dx -= v.dx * 0.18; a.dy -= v.dy * 0.18
        v.dx += a.dx * dt; v.dy += a.dy * dt
        let sp = hypot(v.dx, v.dy), cap: CGFloat = 170, floor: CGFloat = 28
        if sp > cap { v.dx *= cap / sp; v.dy *= cap / sp }
        if sp < floor, sp > 0.01, touch == nil { v.dx *= floor / sp; v.dy *= floor / sp }
        x.x += v.dx * dt; x.y += v.dy * dt
        let W = size.width, H = size.height
        if x.x < 20 { x.x = 20; v.dx = abs(v.dx) }
        if x.x > W - 20 { x.x = W - 20; v.dx = -abs(v.dx) }
        if x.y < 80 { x.y = 80; v.dy = abs(v.dy) }
        if x.y > H - 130 { x.y = H - 130; v.dy = -abs(v.dy) }

        trail.append(x)
        if trail.count > 900 { trail.removeFirst(trail.count - 900) }

        nearest = nil
        for (i, m) in attractors.enumerated() where !m.met {
            let e = hypot(m.p.x - x.x, m.p.y - x.y) - m.core
            if e < (nearest?.edge ?? .infinity) { nearest = (i, e) }
        }
        guard grace <= 0, let n = nearest else { return }
        if n.edge <= 0 {
            paused = true
            let m = attractors[n.index]
            Resonator.shared.play(.meeting(m.res.meeting))
            let cb = onCollide
            DispatchQueue.main.async { cb?(m.soul, m.res) }
        } else if n.edge < Self.feel, t >= nextPulse {
            let k = Double(n.edge / Self.feel)
            Resonator.shared.play(.pulse(Float(0.85 - 0.6 * k)))
            nextPulse = t + 0.32 + 1.2 * k
        }
    }

    func draw(_ ctx: inout GraphicsContext, t: Double) {
        // flow field — short dashes along the field, very faint
        let stepPx: CGFloat = 26
        var dashes = Path()
        var gy: CGFloat = 70
        while gy < size.height - 110 {
            var gx: CGFloat = 13
            while gx < size.width {
                let a = field(at: CGPoint(x: gx, y: gy))
                let m = hypot(a.dx, a.dy)
                if m > 0.5 {
                    let ux = a.dx / m * 4, uy = a.dy / m * 4
                    dashes.move(to: CGPoint(x: gx - ux, y: gy - uy)); dashes.addLine(to: CGPoint(x: gx + ux, y: gy + uy))
                }
                gx += stepPx
            }
            gy += stepPx
        }
        ctx.stroke(dashes, with: .color(SF.blue.opacity(0.11)), lineWidth: SF.line)

        // attractors
        for m in attractors {
            if m.met {
                ctx.stroke(ring(m.p, 4), with: .color(SF.hair), lineWidth: SF.line)
            } else {
                Rings.draw(&ctx, at: m.p, count: 2 + Int(m.strength * 6), gap: 4.5, inner: 3,
                           opacity: 0.45 + 0.45 * m.strength, seed: m.phase, t: t)
            }
        }

        // tether to who you're starting to feel
        if let n = nearest, n.edge < Self.feel, n.edge > 0 {
            let k = 1 - Double(n.edge / Self.feel)
            var p = Path(); p.move(to: x); p.addLine(to: attractors[n.index].p)
            ctx.stroke(p, with: .color(SF.blue.opacity(0.5 * k)), style: StrokeStyle(lineWidth: SF.line, dash: [1.5, 4]))
        }

        // your trajectory
        let chunks = 8
        if trail.count > 2 {
            let per = max(1, trail.count / chunks)
            for c in 0..<chunks {
                let s = c * per, e = min(trail.count - 1, s + per + 1)
                guard e > s else { continue }
                var p = Path(); p.move(to: trail[s])
                for i in (s + 1)...e { p.addLine(to: trail[i]) }
                ctx.stroke(p, with: .color(SF.blue.opacity(0.08 + 0.85 * Double(c + 1) / Double(chunks))), lineWidth: 1)
            }
        }
        ctx.stroke(ring(x, 8), with: .color(SF.blue.opacity(0.5)), lineWidth: SF.line)
        ctx.fill(ring(x, 3.2), with: .color(SF.blue))
    }
}

struct DriftView: View {
    @Environment(Store.self) private var store
    @State private var sim = FieldSim()
    @State private var encounter: Encounter?
    @State private var configuredFor: Int?

    struct Encounter: Identifiable { let soul: Soul; let res: Resonance; var id: UUID { soul.id } }

    var body: some View {
        ZStack {
            Paper()
            GeometryReader { geo in
                TimelineView(.animation(minimumInterval: nil, paused: encounter != nil)) { tl in
                    Canvas { ctx, _ in
                        let t = tl.date.timeIntervalSinceReferenceDate
                        sim.step(t: t)
                        sim.draw(&ctx, t: t)
                    }
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { g in sim.touch = g.location }
                    .onEnded { _ in sim.touch = nil })
                .onAppear { configure(geo.size) }
                .onChange(of: geo.size) { _, s in configure(s, force: true) }
            }
            .ignoresSafeArea()

            if let e = encounter, let me = store.me {
                EncounterView(me: me, other: e.soul, res: e.res) { choice in
                    store.record(e.soul, choice: choice, resonance: e.res)
                    sim.markMet(e.soul.id)
                    sim.paused = false
                    withAnimation(.easeInOut(duration: 0.5)) { encounter = nil; store.inEncounter = false }
                }
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .onDisappear { store.inEncounter = false }
        .onAppear {
            sim.onCollide = { soul, res in
                withAnimation(.easeInOut(duration: 0.5)) { encounter = Encounter(soul: soul, res: res); store.inEncounter = true }
            }
        }
    }

    private func configure(_ size: CGSize, force: Bool = false) {
        guard let me = store.me, size.width > 0 else { return }
        if !force, configuredFor == me.hashValue, !sim.attractors.isEmpty { return }
        sim.configure(me: me, others: store.others, met: Set(store.bonds.map(\.soulID)), size: size)
        configuredFor = me.hashValue
    }
}
