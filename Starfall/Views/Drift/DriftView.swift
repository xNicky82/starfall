import SwiftUI

/// The field physics. A plain class mutated from inside Canvas, so it never triggers SwiftUI updates per frame.
final class DriftSim {
    struct Mote {
        let soul: Soul
        let res: Resonance
        let colors: [Color]
        var p: CGPoint
        var v: CGVector
        let r: CGFloat
        let phase: Double
        var met: Bool
    }
    struct Ripple { var p: CGPoint; var color: Color; var born: Double }

    var motes: [Mote] = []
    var me: CGPoint = .zero
    var meColors: [Color] = [SF.blue]
    let meR: CGFloat = 26
    var size: CGSize = .zero
    var dragging = false
    var paused = false
    var ripples: [Ripple] = []
    var nearest: (index: Int, edge: CGFloat)?
    private var last: Double?
    private var nextPulse: Double = 0
    var onCollide: ((Soul, Resonance) -> Void)?

    static let feel: CGFloat = 150

    func configure(me soul: Soul, others: [Soul], met: Set<UUID>, size: CGSize) {
        self.size = size
        me = CGPoint(x: size.width / 2, y: size.height * 0.5)
        meColors = soul.auraColors
        var rng = SplitMix64(seed: 7)
        motes = others.map { o in
            var p: CGPoint
            repeat {
                p = CGPoint(x: .random(in: 30...(size.width - 30), using: &rng), y: .random(in: 90...(size.height - 140), using: &rng))
            } while hypot(p.x - me.x, p.y - me.y) < 120
            let a = Double.random(in: 0...(2 * .pi), using: &rng)
            return Mote(soul: o, res: Resonance.between(soul, o), colors: o.auraColors, p: p,
                        v: CGVector(dx: cos(a) * 10, dy: sin(a) * 10),
                        r: .random(in: 13...19, using: &rng), phase: .random(in: 0...10, using: &rng),
                        met: met.contains(o.id))
        }
        last = nil
    }

    func markMet(_ id: UUID) {
        guard let i = motes.firstIndex(where: { $0.soul.id == id }) else { return }
        motes[i].met = true
        let dx = motes[i].p.x - me.x, dy = motes[i].p.y - me.y, d = max(1, hypot(dx, dy))
        motes[i].v = CGVector(dx: dx / d * 40, dy: dy / d * 40)
    }

    func step(t: Double) {
        guard let l = last else { last = t; return }
        last = t
        guard !paused, size.width > 0 else { return }
        let dt = min(1.0 / 30, t - l)
        let W = size.width, H = size.height

        for i in motes.indices {
            var m = motes[i]
            let ang = sin(t * 0.21 + m.phase) * .pi + m.phase * 3 + t * 0.05
            m.v.dx += cos(ang) * 9 * dt
            m.v.dy += sin(ang) * 9 * dt
            if !m.met {
                let dx = me.x - m.p.x, dy = me.y - m.p.y, d = max(20, hypot(dx, dy))
                let pull = (m.res.score - 0.30) * 34
                m.v.dx += dx / d * pull * dt
                m.v.dy += dy / d * pull * dt
            }
            m.v.dx *= (1 - 0.35 * dt); m.v.dy *= (1 - 0.35 * dt)
            let sp = hypot(m.v.dx, m.v.dy), cap: CGFloat = 32
            if sp > cap { m.v.dx *= cap / sp; m.v.dy *= cap / sp }
            m.p.x += m.v.dx * dt; m.p.y += m.v.dy * dt
            if m.p.x < m.r { m.p.x = m.r; m.v.dx = abs(m.v.dx) }
            if m.p.x > W - m.r { m.p.x = W - m.r; m.v.dx = -abs(m.v.dx) }
            if m.p.y < 70 { m.p.y = 70; m.v.dy = abs(m.v.dy) }
            if m.p.y > H - 120 { m.p.y = H - 120; m.v.dy = -abs(m.v.dy) }
            motes[i] = m
        }

        for i in motes.indices {
            for j in (i + 1)..<motes.count {
                let dx = motes[j].p.x - motes[i].p.x, dy = motes[j].p.y - motes[i].p.y
                let d = hypot(dx, dy), minD = motes[i].r + motes[j].r
                guard d < minD, d > 0.01 else { continue }
                let nx = dx / d, ny = dy / d, push = (minD - d) / 2
                motes[i].p.x -= nx * push; motes[i].p.y -= ny * push
                motes[j].p.x += nx * push; motes[j].p.y += ny * push
                let rel = (motes[i].v.dx - motes[j].v.dx) * nx + (motes[i].v.dy - motes[j].v.dy) * ny
                if rel > 0 {
                    motes[i].v.dx -= rel * nx; motes[i].v.dy -= rel * ny
                    motes[j].v.dx += rel * nx; motes[j].v.dy += rel * ny
                    if ripples.count < 10 {
                        ripples.append(Ripple(p: CGPoint(x: motes[i].p.x + nx * motes[i].r, y: motes[i].p.y + ny * motes[i].r),
                                              color: motes[i].colors[0], born: t))
                    }
                }
            }
        }
        ripples.removeAll { t - $0.born > 1.6 }

        if !dragging {
            me.x += (W / 2 - me.x) * 0.02 * dt; me.y += (H * 0.5 - me.y) * 0.02 * dt
        }

        nearest = nil
        for (i, m) in motes.enumerated() where !m.met {
            let edge = hypot(m.p.x - me.x, m.p.y - me.y) - m.r - meR
            if edge < (nearest?.edge ?? .infinity) { nearest = (i, edge) }
        }
        if let n = nearest {
            if n.edge <= 0 {
                paused = true
                let m = motes[n.index]
                Resonator.shared.play(.meeting(m.res.meeting))
                ripples.append(Ripple(p: me, color: m.colors[0], born: t))
                let cb = onCollide
                DispatchQueue.main.async { cb?(m.soul, m.res) }
            } else if n.edge < Self.feel, t >= nextPulse {
                let k = Double(n.edge / Self.feel)
                Resonator.shared.play(.pulse(Float(0.85 - 0.6 * k)))
                nextPulse = t + 0.32 + 1.2 * k
            }
        }
    }

    func draw(_ ctx: inout GraphicsContext, t: Double) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
        for r in ripples {
            let age = (t - r.born) / 1.6, rad = 10 + 80 * age
            ctx.stroke(Celestial.disk(r.p, rad), with: .color(r.color.opacity(0.6 * (1 - age))), lineWidth: 1.4)
        }
        if let n = nearest, n.edge < Self.feel, n.edge > 0 {
            let m = motes[n.index], k = 1 - Double(n.edge / Self.feel)
            var p = Path(); p.move(to: me); p.addLine(to: m.p)
            ctx.stroke(p, with: .color(m.colors[0].opacity(0.7 * k)),
                       style: StrokeStyle(lineWidth: 1.4, dash: [2, 6], dashPhase: -t * 20))
        }
        for m in motes {
            Celestial.planet(&ctx, center: m.p, radius: m.r * 0.6, colors: m.colors,
                             intensity: m.met ? 0.2 : 0.8, light: t * 0.25 + m.phase, spread: 1)
        }
        let k = nearest.map { max(0, 1 - Double($0.edge / Self.feel)) } ?? 0
        Celestial.planet(&ctx, center: me, radius: meR * 0.62, colors: meColors,
                         intensity: 1.15 + 0.5 * k, light: t * 0.18, spread: 1.5)
    }
}

struct DriftView: View {
    @Environment(Store.self) private var store
    @State private var sim = DriftSim()
    @State private var encounter: Encounter?
    @State private var configuredFor: Int?

    struct Encounter: Identifiable { let soul: Soul; let res: Resonance; var id: UUID { soul.id } }

    var body: some View {
        ZStack {
            GeometryReader { geo in
                TimelineView(.animation(minimumInterval: nil, paused: encounter != nil)) { tl in
                    Canvas { ctx, _ in
                        let t = tl.date.timeIntervalSinceReferenceDate
                        sim.step(t: t)
                        sim.draw(&ctx, t: t)
                    }
                }
                .stipple(specks: 0.0035)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        if !sim.dragging, hypot(g.startLocation.x - sim.me.x, g.startLocation.y - sim.me.y) > 70 { return }
                        sim.dragging = true
                        sim.me = CGPoint(x: min(max(30, g.location.x), geo.size.width - 30),
                                         y: min(max(80, g.location.y), geo.size.height - 130))
                    }
                    .onEnded { _ in sim.dragging = false })
                .onAppear { configure(geo.size) }
                .onChange(of: geo.size) { _, s in configure(s, force: true) }
            }
            .ignoresSafeArea()

            if let e = encounter, let me = store.me {
                EncounterView(me: me, other: e.soul, res: e.res) { choice in
                    store.record(e.soul, choice: choice, resonance: e.res)
                    sim.markMet(e.soul.id)
                    sim.paused = false
                    withAnimation(.easeInOut(duration: 0.6)) { encounter = nil; store.inEncounter = false }
                }
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .onDisappear { store.inEncounter = false }
        .onAppear {
            sim.onCollide = { soul, res in
                withAnimation(.easeInOut(duration: 0.6)) { encounter = Encounter(soul: soul, res: res); store.inEncounter = true }
            }
        }
    }

    private func configure(_ size: CGSize, force: Bool = false) {
        guard let me = store.me, size.width > 0 else { return }
        if !force, configuredFor == me.hashValue, !sim.motes.isEmpty { return }
        sim.configure(me: me, others: store.others, met: Set(store.bonds.map(\.soulID)), size: size)
        configuredFor = me.hashValue
    }
}
