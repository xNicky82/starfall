import SwiftUI

struct ConstellationView: View {
    @Environment(Store.self) private var store

    var body: some View {
        let bonded = store.bonded.compactMap { b in store.soul(b.soulID).map { (b, $0) } }
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let c = CGPoint(x: w / 2, y: h * 0.46)
            let pts: [CGPoint] = bonded.enumerated().map { i, pair in
                let a = Double(i) * 2.399963 - .pi / 2
                let rad = 70 + (1 - pair.0.score) * 170 + Double(i % 3) * 12
                return CGPoint(x: c.x + CGFloat(cos(a) * rad), y: c.y + CGFloat(sin(a) * rad))
            }
            ZStack {
                TimelineView(.animation) { tl in
                    Canvas { ctx, size in
                        let t = tl.date.timeIntervalSinceReferenceDate
                        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
                        for p in pts {
                            var path = Path(); path.move(to: c); path.addLine(to: p)
                            ctx.stroke(path, with: .color(.white.opacity(0.16)), lineWidth: 1)
                        }
                        if pts.count > 1 {
                            var path = Path(); path.addLines(pts + [pts[0]])
                            ctx.stroke(path, with: .color(.white.opacity(0.07)), lineWidth: 1)
                        }
                        for (i, p) in pts.enumerated() {
                            Celestial.planet(&ctx, center: p, radius: 7, colors: bonded[i].1.auraColors,
                                             light: t * 0.2 + Double(i), spread: 1)
                        }
                        if let me = store.me {
                            Celestial.planet(&ctx, center: c, radius: 15, colors: me.auraColors, intensity: 1.15,
                                             light: t * 0.15, spread: 1.4)
                        }
                    }
                }
                .stipple(specks: 0.0035)
                ForEach(Array(bonded.enumerated()), id: \.0) { i, pair in
                    Text(pair.1.name).caption(8, SF.mist).position(x: pts[i].x, y: pts[i].y + 30)
                }
            }
        }
        .ignoresSafeArea()
    }
}
