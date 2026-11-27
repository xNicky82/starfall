import SwiftUI

/// Two lights have touched. Feel it, read it, then slide: drift on, or bond.
struct EncounterView: View {
    var me: Soul
    var other: Soul
    var res: Resonance
    var onChoice: (BondRecord.Choice) -> Void

    @State private var appeared = Date()

    private var tint: Color {
        switch res.meeting { case .mend: return SF.blue; case .spark: return Element.sol.color; case .clash: return Element.ember.color }
    }

    var body: some View {
        ZStack {
            SF.paper.opacity(0.92).ignoresSafeArea()
            SanctuaryBackground(glow: tint).opacity(0.9)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    Text("Collision").eyebrow(tint).padding(.top, 20)
                    collisionCanvas.frame(height: 250)
                    Text(res.meeting.word).font(SF.display(44)).tracking(14).foregroundStyle(SF.ink)
                    Text(res.meeting.line).font(SF.body(15)).foregroundStyle(SF.mist)
                    Text("with \(other.name)").font(SF.display(18)).foregroundStyle(SF.ink).padding(.top, 2)

                    VStack(spacing: 14) {
                        HStack {
                            Text("Resonance").eyebrow()
                            Spacer()
                            Text("\(Int((res.score * 100).rounded()))").font(SF.display(28)).monospacedDigit().foregroundStyle(SF.ink)
                        }
                        meter("Values", res.values, .aether)
                        meter("Interests", res.interests, .sol)
                        meter("Traits", res.traits, .tide)
                    }
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: 24).fill(SF.card))

                    if !res.sharedValues.isEmpty || !res.sharedInterests.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Where you meet").eyebrow()
                            chips(res.sharedValues.prefix(4).compactMap(Catalog.facet), filled: true)
                            chips(res.sharedInterests.prefix(6).compactMap(Catalog.facet), filled: false)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(RoundedRectangle(cornerRadius: 24).fill(SF.card))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(other.name) holds").eyebrow()
                        FlowRow(items: Array(other.topValues.prefix(4)))
                        ElementBar(soul: other).padding(.top, 4)
                    }
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: 24).fill(SF.card))

                    Color.clear.frame(height: 110)
                }
                .padding(.horizontal, 22)
            }
            VStack {
                Spacer()
                DualSlotSlider(leftLabel: "drift on", rightLabel: "bond", colors: me.auraColors, rightTint: tint,
                               onLeft: { onChoice(.released) },
                               onRight: { Resonator.shared.play(.mend); onChoice(.bonded) })
                    .padding(.horizontal, 22).padding(.bottom, 18)
            }
        }
    }

    private var collisionCanvas: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                let age = t - appeared.timeIntervalSinceReferenceDate
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let r: CGFloat = 52
                let settle = min(1, age / 1.2)
                var sep: CGFloat
                var jitter: CGFloat = 0
                switch res.meeting {
                case .mend:  sep = r * (2.4 - 1.5 * settle) + 6 * sin(t * 1.1)
                case .spark: sep = r * (2.4 - 0.7 * settle) + 4 * sin(t * 3.7); jitter = 1.5
                case .clash: sep = r * (2.0 + 0.6 * settle); jitter = CGFloat(4 * max(0, 1 - age / 1.5))
                }
                let jx = jitter * CGFloat(sin(t * 53)), jy = jitter * CGFloat(cos(t * 47))
                let a = CGPoint(x: c.x - sep / 2 + jx, y: c.y + jy), b = CGPoint(x: c.x + sep / 2 - jx, y: c.y - jy)

                if res.meeting == .mend {
                    // a shared light where they overlap
                    let mr = r * 1.6
                    ctx.fill(Path(ellipseIn: CGRect(x: c.x - mr, y: c.y - mr, width: mr * 2, height: mr * 2)),
                             with: .radialGradient(Gradient(colors: [Color.white.opacity(0.8 * settle), .clear]),
                                                   center: c, startRadius: 0, endRadius: mr))
                }
                if res.meeting == .spark {
                    for k in 0..<7 {
                        let ang = Double(k) * 0.9 + t * 2.3
                        let len = 10 + 14 * abs(sin(t * 5 + Double(k)))
                        var p = Path(); p.move(to: c)
                        p.addLine(to: CGPoint(x: c.x + cos(ang) * len, y: c.y + sin(ang) * len))
                        ctx.stroke(p, with: .color(Element.sol.color.opacity(0.8)), lineWidth: 1.2)
                    }
                }
                OrbRenderer.draw(&ctx, at: a, radius: r, colors: other.auraColors, time: t, phase: 3)
                var top = ctx
                if res.meeting == .mend { top.opacity = 0.85 }
                OrbRenderer.draw(&top, at: b, radius: r, colors: me.auraColors, time: t)
                if res.meeting == .clash {
                    var p = Path(); p.move(to: CGPoint(x: c.x, y: c.y - r)); p.addLine(to: CGPoint(x: c.x, y: c.y + r))
                    ctx.stroke(p, with: .color(Element.ember.color.opacity(0.6)), lineWidth: 1.5)
                }
            }
        }
    }

    private func meter(_ name: String, _ v: Double, _ el: Element) -> some View {
        HStack(spacing: 12) {
            Text(name).font(SF.label(12)).foregroundStyle(SF.mist).frame(width: 70, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(SF.faint)
                    Capsule().fill(el.color).frame(width: g.size.width * min(1, max(0.02, v)))
                }
            }
            .frame(height: 6)
            Text("\(Int((v * 100).rounded()))").font(SF.label(12)).monospacedDigit().foregroundStyle(SF.mist).frame(width: 28, alignment: .trailing)
        }
    }

    private func chips(_ facets: [Facet], filled: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(facets) { f in
                    HStack(spacing: 6) {
                        Glyph(element: f.element, size: 8)
                        Text(f.name).font(SF.label(12)).foregroundStyle(filled ? .white : SF.ink)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Capsule().fill(filled ? f.element.color : Color.white.opacity(0.6)))
                }
            }
        }
    }
}
