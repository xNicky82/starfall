import SwiftUI

/// Their world rises; your star hangs above it.
/// Pull your star down into their horizon to bond. Throw it back up to drift on.
struct EncounterView: View {
    var me: Soul
    var other: Soul
    var res: Resonance
    var onChoice: (BondRecord.Choice) -> Void

    @State private var appeared = Date()
    @State private var drag: Double? = nil
    @State private var releaseFrom: Double = 0
    @State private var releaseAt = Date.distantPast
    @State private var decision: BondRecord.Choice? = nil
    @State private var decidedAt = Date.distantPast
    @State private var lastTick = 0
    @State private var textIn = 0.0

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let R = w * 0.56, horizon = h * 0.56, gap = w * 0.22, trail = w * 0.26
            ZStack {
                TimelineView(.animation) { tl in
                    Canvas { ctx, size in
                        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
                        draw(&ctx, now: tl.date, w: w, h: h, R: R, horizon: horizon, gap: gap, trail: trail)
                    }
                }
                .stipple(specks: 0.0035)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        guard decision == nil else { return }
                        let p = min(max(Double(v.translation.height / gap), -1), 1)
                        let tick = Int(p * 8)
                        if tick != lastTick { lastTick = tick; Resonator.shared.tick() }
                        drag = p
                    }
                    .onEnded { _ in
                        guard let p = drag else { return }
                        drag = nil
                        if p > 0.82 { decide(.bonded) }
                        else if p < -0.6 { decide(.released) }
                        else { releaseFrom = p; releaseAt = .now }
                    })

                VStack(spacing: 10) {
                    Text(other.name).caption(15, SF.paper)
                    Text(res.meeting.rawValue).caption(9, SF.mist)
                    if !res.sharedValues.isEmpty {
                        Text(res.sharedValues.prefix(3).compactMap { Catalog.facet($0)?.name }.joined(separator: "  ·  "))
                            .caption(8.5, SF.mist)
                    }
                }
                .opacity(textIn * (decision == nil ? 1 : 0))
                .position(x: w / 2, y: horizon + R * 0.42)
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .onAppear { withAnimation(.easeIn(duration: 1.0).delay(1.0)) { textIn = 1 } }
    }

    private func decide(_ c: BondRecord.Choice) {
        decision = c
        decidedAt = .now
        if c == .bonded {
            Resonator.shared.play(.snap)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { Resonator.shared.play(.mend) }
        } else {
            Resonator.shared.play(.tick)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (c == .bonded ? 1.3 : 0.8)) { onChoice(c) }
    }

    private func rnd(_ n: Double) -> Double { let x = sin(n * 12.9898) * 43758.5453; return x - floor(x) }

    private func draw(_ ctx: inout GraphicsContext, now: Date, w: CGFloat, h: CGFloat, R: CGFloat,
                      horizon: CGFloat, gap: CGFloat, trail: CGFloat) {
        let t = now.timeIntervalSinceReferenceDate
        let age = now.timeIntervalSince(appeared)
        let rise = ease(age / 1.4)
        let c = CGPoint(x: w / 2, y: horizon + R + CGFloat(1 - rise) * h * 0.6)

        var pull: Double
        if let d = drag { pull = d } else {
            let dt = now.timeIntervalSince(releaseAt)
            pull = dt > 2 ? 0 : releaseFrom * exp(-dt * 6) * cos(dt * 9)
        }
        let entry = ease((age - 0.7) / 1.1)
        var alpha = 1.0, flash = 0.0, plunge = 0.0, fly = 0.0
        if let d = decision {
            let dt = now.timeIntervalSince(decidedAt)
            if d == .bonded {
                pull = 1; plunge = min(1, dt / 0.22); alpha = max(0, 1 - dt / 0.22)
                flash = dt < 0.22 ? 0 : exp(-(dt - 0.22) * 2.2)
            } else {
                fly = dt; alpha = max(0, 1 - dt / 0.7)
            }
        }

        var colors = other.auraColors
        var intensity = 1.0 + 0.05 * sin(t * 1.2)
        var light = -Double.pi / 2
        switch res.meeting {
        case .mend:
            colors = Array(other.auraColors.prefix(2)) + [me.auraColors[0]]
            intensity += 0.3 * max(0, pull)
        case .spark:
            intensity += 0.22 * (0.5 + 0.5 * sin(t * 11) * sin(t * 3.7))
        case .clash:
            light += 0.25 * sin(t * 17) * max(0.25, 1 - age / 2)
            intensity = 0.75 + 0.3 * abs(sin(t * 7.3))
            colors = [other.auraColors[0], Element.ember.color]
        }
        Celestial.planet(&ctx, center: c, radius: R, colors: colors, intensity: intensity + flash, light: light,
                         spread: 1.25 + 0.3 * CGFloat(flash))

        if res.meeting == .spark && rise > 0.9 {
            for k in 0..<6 {
                let slot = floor(t * 7) + Double(k) * 13
                let a = -Double.pi / 2 + (rnd(slot) - 0.5) * 1.9
                let rr = R * CGFloat(1.0 + 0.05 * rnd(slot + 3))
                let p = CGPoint(x: c.x + CGFloat(cos(a)) * rr, y: c.y + CGFloat(sin(a)) * rr)
                Celestial.star(&ctx, at: p, radius: 4 + 6 * CGFloat(rnd(slot + 7)), color: Element.sol.color, intensity: 0.9)
            }
        }

        guard entry > 0, alpha > 0 else { return }
        let rest = horizon - gap
        let bob = 3 * sin(t * 1.4) * (1 - abs(pull))
        var y = rest - CGFloat(1 - entry) * (rest + trail + 60)
        y += pull > 0 ? (gap - 4) * CGFloat(pull) : gap * 0.9 * CGFloat(pull)
        y += CGFloat(bob) + CGFloat(plunge) * 26 - CGFloat(fly * fly) * 1400
        let x = w / 2 + (res.meeting == .clash ? CGFloat(1.5 * sin(t * 53)) : 0)
        Celestial.comet(&ctx, head: CGPoint(x: x, y: y), angle: fly > 0 ? .pi / 2 : -.pi / 2,
                        length: trail * CGFloat(1 + 0.5 * abs(pull) + 1.2 * (1 - entry)) + CGFloat(fly) * 300,
                        intensity: alpha, headColor: me.hue, head: 1.6)
    }
}
