import SwiftUI

/// Draws a soul: a crisp Bauhaus circle holding soft, slowly turning light.
enum OrbRenderer {
    static func draw(_ ctx: inout GraphicsContext, at c: CGPoint, radius r: CGFloat,
                     colors: [Color], time t: Double, energy: Double = 1, ring: Bool = true, phase: Double = 0) {
        let cols = colors.isEmpty ? [SF.blue] : colors
        let breath = 1 + 0.06 * sin(t * 1.3 + phase)

        // Halo
        let hr = r * 2.3 * breath
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - hr, y: c.y - hr, width: hr * 2, height: hr * 2)),
                 with: .radialGradient(Gradient(colors: [cols[0].opacity(0.28 * energy), cols[0].opacity(0)]),
                                       center: c, startRadius: r * 0.4, endRadius: hr))

        // Body: each energy is a blob of light orbiting inside the circle.
        var inner = ctx
        inner.clip(to: Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)))
        inner.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                   with: .color(.white.opacity(0.55)))
        for (i, col) in cols.enumerated() {
            let a = t * (0.35 + Double(i) * 0.12) + Double(i) * 2.1 + phase
            let o = CGPoint(x: c.x + cos(a) * r * 0.38, y: c.y + sin(a) * r * 0.38)
            let br = r * (i == 0 ? 1.15 : 0.9)
            inner.fill(Path(ellipseIn: CGRect(x: o.x - br, y: o.y - br, width: br * 2, height: br * 2)),
                       with: .radialGradient(Gradient(colors: [col.opacity(0.95), col.opacity(0)]),
                                             center: o, startRadius: 0, endRadius: br))
        }
        // Inner light
        let cr = r * 0.55
        let co = CGPoint(x: c.x - r * 0.18, y: c.y - r * 0.22)
        inner.fill(Path(ellipseIn: CGRect(x: co.x - cr, y: co.y - cr, width: cr * 2, height: cr * 2)),
                   with: .radialGradient(Gradient(colors: [.white.opacity(0.75), .white.opacity(0)]),
                                         center: co, startRadius: 0, endRadius: cr))
        if ring {
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                       with: .color(SF.ink.opacity(0.14)), lineWidth: 0.75)
        }
    }
}

struct OrbView: View {
    var colors: [Color]
    var energy: Double = 1
    var phase: Double = 0
    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let r = min(size.width, size.height) / 2 / 2.3
                OrbRenderer.draw(&ctx, at: CGPoint(x: size.width / 2, y: size.height / 2), radius: r,
                                 colors: colors, time: tl.date.timeIntervalSinceReferenceDate, energy: energy, phase: phase)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Bauhaus glyph for each element.
struct Glyph: View {
    var element: Element
    var size: CGFloat = 14
    var filled = true
    var body: some View {
        let c = element.color
        Group {
            switch element {
            case .ember:  Triangle().fill(c)
            case .tide:   Circle().fill(c)
            case .grove:  Rectangle().fill(c)
            case .sol:    HalfCircle().fill(c)
            case .aether: Circle().stroke(c, lineWidth: size * 0.22)
            }
        }
        .frame(width: size, height: size)
        .opacity(filled ? 1 : 0.35)
    }
}

struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.closeSubpath() }
    }
}
struct HalfCircle: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in p.addArc(center: CGPoint(x: r.midX, y: r.maxY - r.height * 0.2), radius: r.width / 2,
                             startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false); p.closeSubpath() }
    }
}
