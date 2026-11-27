import SwiftUI

/// The only "button": pull the falling star down into the horizon.
struct DescentGate: View {
    var ready: Bool
    var colors: [Color]
    /// Fractions of this view's size.
    var horizon: CGFloat          // y of the planet's top, 0…1 of height
    var radius: CGFloat           // × width
    var gap: CGFloat              // star rest height above horizon, × width
    var trail: CGFloat            // × width
    var spread: CGFloat = 0.45
    var alwaysVisible = false
    var headColor: Color = SF.ember
    var onCommit: () -> Void

    @State private var readyAt: Date? = nil
    @State private var drag: Double? = nil
    @State private var releaseFrom: Double = 0
    @State private var releaseAt = Date.distantPast
    @State private var committedAt: Date? = nil
    @State private var flashAt = Date.distantPast
    @State private var lastTick = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let hy = h * horizon, R = w * radius, gp = w * gap, tr = w * trail
            TimelineView(.animation) { tl in
                Canvas { ctx, _ in
                    let now = tl.date, t = now.timeIntervalSinceReferenceDate
                    let s = state(now)
                    Celestial.planet(&ctx, center: CGPoint(x: w / 2, y: hy + R), radius: R, colors: colors,
                                     intensity: 1.0 + 0.3 * s.pull + 0.9 * s.flash, light: -.pi / 2,
                                     spread: spread * (1 + 0.2 * CGFloat(s.flash)))
                    if s.visible > 0.001 {
                        let rest = hy - gp
                        let bob = CGFloat(sin(t * 1.4)) * 3 * CGFloat(1 - s.pull)
                        let y = rest - CGFloat(1 - s.entry) * (rest + tr + 40) + (gp - 4) * CGFloat(s.pull) + bob + CGFloat(s.plunge) * 26
                        Celestial.comet(&ctx, head: CGPoint(x: w / 2, y: y),
                                        length: tr * (1 + 0.6 * CGFloat(s.pull) + 1.2 * CGFloat(1 - s.entry)),
                                        intensity: s.visible, headColor: headColor, head: 1.6)
                    }
                }
            }
            .stipple(specks: 0.0012)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { g in
                    guard ready, committedAt == nil else { return }
                    let p = min(max(0, Double(g.translation.height / (gp - 4))), 1)
                    let tick = Int(p * 8)
                    if tick != lastTick { lastTick = tick; Resonator.shared.tick() }
                    drag = p
                }
                .onEnded { _ in
                    guard let p = drag else { return }
                    drag = nil
                    if p > 0.82 { commit() } else { releaseFrom = p; releaseAt = .now }
                })
        }
        .onAppear { if ready || alwaysVisible { readyAt = .now } }
        .onChange(of: ready) { _, r in if r { readyAt = .now } }
    }

    private func commit() {
        committedAt = .now
        flashAt = Date().addingTimeInterval(0.22)
        Resonator.shared.play(.snap)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            onCommit()
            committedAt = nil
            releaseFrom = 0
            readyAt = .now
        }
    }

    private struct S { var entry, visible, pull, plunge, flash: Double }

    private func state(_ now: Date) -> S {
        var entry = 1.0
        if !alwaysVisible {
            entry = (ready && readyAt != nil) ? ease(now.timeIntervalSince(readyAt!) / 1.1) : 0
        }
        var visible = alwaysVisible ? (ready ? 1 : 0.5) : (ready ? 1.0 : 0)
        var pull: Double
        if let d = drag { pull = d } else {
            let dt = now.timeIntervalSince(releaseAt)
            pull = dt > 2 ? 0 : releaseFrom * exp(-dt * 6) * cos(dt * 9)
        }
        var plunge = 0.0
        if let c = committedAt {
            let dt = now.timeIntervalSince(c)
            pull = 1
            plunge = min(1, dt / 0.22)
            visible *= max(0, 1 - dt / 0.22)
        }
        let fd = now.timeIntervalSince(flashAt)
        let flash = fd < 0 ? 0 : exp(-fd * 3)
        return S(entry: entry, visible: visible, pull: max(-0.2, pull), plunge: plunge, flash: flash)
    }
}
