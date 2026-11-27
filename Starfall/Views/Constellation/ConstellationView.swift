import SwiftUI

/// The souls you bonded with, set as stars around you.
struct ConstellationView: View {
    @Environment(Store.self) private var store

    var body: some View {
        let me = store.me
        let bonded = store.bonded.compactMap { b in store.soul(b.soulID).map { (b, $0) } }
        ZStack {
            SanctuaryBackground(glow: me?.hue ?? SF.blue)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Text("Constellation").eyebrow(me?.hue ?? SF.blue).padding(.top, 8)
                    sky(bonded: bonded, me: me).frame(height: 340)
                    if bonded.isEmpty {
                        Text("No bonds yet.\nDrift until your light touches someone, then slide to bond.")
                            .font(SF.body(14)).foregroundStyle(SF.mist).multilineTextAlignment(.center)
                    }
                    ForEach(bonded, id: \.0.id) { rec, soul in
                        HStack(spacing: 14) {
                            OrbView(colors: soul.auraColors, phase: Double(soul.name.count)).frame(width: 92, height: 92).padding(-20)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(soul.name).font(SF.display(18)).foregroundStyle(SF.ink)
                                Text(soul.topValues.prefix(3).map(\.0.name).joined(separator: " · "))
                                    .font(SF.body(12)).foregroundStyle(SF.mist)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(rec.meeting.word).font(SF.label(10)).tracking(2).foregroundStyle(SF.mist)
                                Text("\(Int((rec.score * 100).rounded()))").font(SF.display(22)).monospacedDigit().foregroundStyle(SF.ink)
                            }
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 24).fill(SF.card))
                    }
                    Color.clear.frame(height: 110)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func sky(bonded: [(BondRecord, Soul)], me: Soul?) -> some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                for k in 1...3 {
                    let rr = CGFloat(k) * 50
                    ctx.stroke(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)),
                               with: .color(SF.faint), lineWidth: 0.6)
                }
                let pts: [CGPoint] = bonded.enumerated().map { i, pair in
                    let (rec, _) = pair
                    let ang = Double(i) * 2.399963 + t * 0.03 // golden angle
                    let rad = 60 + (1 - rec.score) * 180
                    return CGPoint(x: c.x + cos(ang) * rad, y: c.y + sin(ang) * rad)
                }
                for p in pts {
                    var path = Path(); path.move(to: c); path.addLine(to: p)
                    ctx.stroke(path, with: .color(SF.blue.opacity(0.35)), lineWidth: 0.8)
                }
                if pts.count > 1 {
                    var path = Path(); path.addLines(pts + [pts[0]])
                    ctx.stroke(path, with: .color(SF.ink.opacity(0.08)), lineWidth: 0.6)
                }
                for (i, p) in pts.enumerated() {
                    OrbRenderer.draw(&ctx, at: p, radius: 13, colors: bonded[i].1.auraColors, time: t, phase: Double(i))
                }
                if let me { OrbRenderer.draw(&ctx, at: c, radius: 24, colors: me.auraColors, time: t) }
            }
        }
    }
}
