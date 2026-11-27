import SwiftUI

/// Trajectories are cheap but not free; share them across views.
final class TrajectoryCache {
    static let shared = TrajectoryCache()
    private var store: [String: [SIMD3<Double>]] = [:]
    func points(_ q: LorenzParams, steps: Int) -> [SIMD3<Double>] {
        let key = "\(q.sigma)|\(q.rho)|\(q.beta)|\(steps)"
        if let p = store[key] { return p }
        let p = Lorenz.trajectory(q, steps: steps)
        if store.count > 64 { store.removeAll() }
        store[key] = p
        return p
    }
}

/// A soul drawn as its attractor — one blue hairline, like a plotter.
struct AttractorView: View {
    var params: LorenzParams
    var steps = 5000
    var color: Color = SF.blue
    var lineWidth: CGFloat = 0.5
    /// Seconds to draw itself in (0 = already drawn).
    var drawIn: Double = 0
    /// Radians per second of slow turning (0 = still).
    var spin: Double = 0.05
    var axes = false

    var body: some View {
        // TimelineView keeps its first content closure; rebuild it whenever the inputs change.
        let q = params, n0 = steps, col = color, lw = lineWidth, dIn = drawIn, sp = spin, ax = axes
        let born = Date()
        return TimelineView(.animation(minimumInterval: 1 / 30, paused: sp == 0 && dIn == 0)) { tl in
            Canvas { ctx, size in
                let pts = TrajectoryCache.shared.points(q, steps: n0)
                let t = tl.date.timeIntervalSince(born)
                let inset: CGFloat = ax ? 26 : 2
                let rect = CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2)
                if ax { Self.drawAxes(&ctx, rect: rect) }
                let n = dIn > 0 ? Int(Double(pts.count) * ease(t / dIn)) : pts.count
                let p = Lorenz.path(pts, yaw: q.yaw + t * sp, pitch: q.pitch, in: rect, upTo: n)
                ctx.stroke(p, with: .color(col.opacity(0.8)), lineWidth: lw)
            }
        }
        .id(q)
    }

    private static func drawAxes(_ ctx: inout GraphicsContext, rect: CGRect) {
        var a = Path()
        a.move(to: CGPoint(x: rect.minX - 6, y: rect.maxY + 6)); a.addLine(to: CGPoint(x: rect.maxX + 6, y: rect.maxY + 6))
        ctx.stroke(a, with: .color(SF.hair), lineWidth: SF.line)
        for i in 0...8 {
            let x = rect.minX + rect.width * CGFloat(i) / 8
            var tk = Path(); tk.move(to: CGPoint(x: x, y: rect.maxY + 6)); tk.addLine(to: CGPoint(x: x, y: rect.maxY + (i % 4 == 0 ? 12 : 9)))
            ctx.stroke(tk, with: .color(SF.hair), lineWidth: SF.line)
        }
    }
}

/// Plotter rings: a soul's pull drawn as nested, slightly eccentric circles.
enum Rings {
    static func draw(_ ctx: inout GraphicsContext, at c: CGPoint, count: Int, gap: CGFloat = 6, inner: CGFloat = 4,
                     color: Color = SF.blue, opacity: Double = 0.85, seed: Double = 0, t: Double = 0, width: CGFloat = SF.line) {
        guard count > 0 else { return }
        for i in 0..<count {
            let f = Double(i) / Double(max(1, count - 1))
            let a = seed * 2.3 + t * 0.2
            let off = CGFloat(i) * 0.9
            let ci = CGPoint(x: c.x + CGFloat(cos(a)) * off, y: c.y + CGFloat(sin(a)) * off)
            ctx.stroke(ring(ci, inner + CGFloat(i) * gap), with: .color(color.opacity(opacity * (1 - 0.35 * f))), lineWidth: width)
        }
    }
}
