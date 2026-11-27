import SwiftUI

/// The two bodies everything is drawn from: a dark planet with a lit horizon, and a falling star.
enum Celestial {
    static func disk(_ c: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    static func halo(_ r: CGFloat, spread: CGFloat) -> CGFloat { max(r * 0.75, 22) * spread }

    /// Dark body, light behind it. `light` is the direction the light comes from (radians).
    static func planet(_ ctx: inout GraphicsContext, center c: CGPoint, radius r: CGFloat, colors: [Color],
                       intensity: Double = 1, light: Double = -.pi / 2, spread: CGFloat = 1) {
        let cols = colors.isEmpty ? [SF.blue] : Array(colors.prefix(3))
        var g = ctx
        g.blendMode = .plusLighter
        let d = r * 0.2
        let outer = r + halo(r, spread: spread) + d
        for (i, col) in cols.enumerated() {
            let a = light + Double(i) * 2.2
            let k = (i == 0 ? 1.0 : 0.6) * intensity
            let s = CGPoint(x: c.x + CGFloat(cos(a)) * d, y: c.y + CGFloat(sin(a)) * d)
            g.fill(disk(s, outer), with: .radialGradient(Gradient(stops: [
                .init(color: .white.opacity(min(1, 0.95 * k)), location: 0),
                .init(color: col.opacity(min(1, 0.85 * k)), location: 0.04),
                .init(color: col.opacity(min(1, 0.42 * k)), location: 0.14),
                .init(color: col.opacity(min(1, 0.13 * k)), location: 0.42),
                .init(color: col.opacity(0), location: 1),
            ]), center: s, startRadius: r - d, endRadius: outer))
        }
        ctx.fill(disk(c, r), with: .color(.black))
    }

    static func trail(_ ctx: inout GraphicsContext, from h: CGPoint, to tail: CGPoint, width: CGFloat,
                      color: Color = .white, intensity: Double = 1) {
        let len = hypot(tail.x - h.x, tail.y - h.y)
        guard len > 1 else { return }
        var g = ctx
        g.blendMode = .plusLighter
        let px = -(tail.y - h.y) / len, py = (tail.x - h.x) / len
        func wedge(_ w: CGFloat) -> Path {
            Path { p in
                p.move(to: CGPoint(x: h.x + px * w / 2, y: h.y + py * w / 2))
                p.addLine(to: tail)
                p.addLine(to: CGPoint(x: h.x - px * w / 2, y: h.y - py * w / 2))
                p.closeSubpath()
            }
        }
        g.fill(wedge(width * 4), with: .linearGradient(
            Gradient(colors: [color.opacity(0.3 * intensity), color.opacity(0)]), startPoint: h, endPoint: tail))
        g.fill(wedge(width), with: .linearGradient(Gradient(stops: [
            .init(color: color.opacity(intensity), location: 0),
            .init(color: color.opacity(0.6 * intensity), location: 0.45),
            .init(color: color.opacity(0), location: 1),
        ]), startPoint: h, endPoint: tail))
    }

    static func star(_ ctx: inout GraphicsContext, at h: CGPoint, radius: CGFloat, color: Color = SF.ember, intensity: Double = 1) {
        var g = ctx
        g.blendMode = .plusLighter
        g.fill(disk(h, radius), with: .radialGradient(Gradient(stops: [
            .init(color: .white.opacity(intensity), location: 0),
            .init(color: color.opacity(0.95 * intensity), location: 0.22),
            .init(color: color.opacity(0.35 * intensity), location: 0.55),
            .init(color: color.opacity(0), location: 1),
        ]), center: h, startRadius: 0, endRadius: radius))
    }

    /// `angle` points from the head back along the trail (up = -π/2).
    static func comet(_ ctx: inout GraphicsContext, head h: CGPoint, angle: Double = -.pi / 2, length: CGFloat,
                      width: CGFloat = 2.6, intensity: Double = 1, headColor: Color = SF.ember, head: CGFloat = 1) {
        guard intensity > 0.001 else { return }
        let tail = CGPoint(x: h.x + CGFloat(cos(angle)) * length, y: h.y + CGFloat(sin(angle)) * length)
        trail(&ctx, from: h, to: tail, width: width, intensity: intensity)
        star(&ctx, at: h, radius: (6 + 8 * CGFloat(intensity)) * head, color: headColor, intensity: intensity)
    }
}

/// A small planet, printed.
struct PlanetGlyph: View {
    var colors: [Color]
    var radius: CGFloat
    var intensity: Double = 1
    var spread: CGFloat = 1
    var animated = true

    var body: some View {
        let size = (radius + Celestial.halo(radius, spread: spread)) * 2 + 8
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !animated)) { tl in
            Canvas { ctx, s in
                let t = tl.date.timeIntervalSinceReferenceDate
                Celestial.planet(&ctx, center: CGPoint(x: s.width / 2, y: s.height / 2), radius: radius, colors: colors,
                                 intensity: intensity, light: -.pi / 2 + (animated ? t * 0.3 : 0), spread: spread)
            }
        }
        .frame(width: size, height: size)
        .stipple(seed: seed(colors.description))
    }
}
