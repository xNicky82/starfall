import SwiftUI

// MARK: - Gather: every interest is a distant star. Touch it and it becomes a lit world.

struct InterestField: View {
    @Binding var soul: Soul
    private let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)

    var body: some View {
        LazyVGrid(columns: cols, spacing: 6) {
            ForEach(Catalog.interests) { f in
                let on = soul.interests[f.id] != nil
                InterestStar(facet: f, on: on)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.5)) { soul.toggleInterest(f.id) }
                        Resonator.shared.play(.snap)
                    }
            }
        }
    }
}

struct InterestStar: View {
    var facet: Facet
    var on: Bool
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Canvas { ctx, s in
                    Celestial.star(&ctx, at: CGPoint(x: s.width / 2, y: s.height / 2), radius: 9, color: .white, intensity: 0.55)
                }
                .opacity(on ? 0 : 1)
                Canvas { ctx, s in
                    Celestial.planet(&ctx, center: CGPoint(x: s.width / 2, y: s.height / 2), radius: 9,
                                     colors: [facet.element.color], intensity: 1.15, spread: 1.05)
                }
                .opacity(on ? 1 : 0)
            }
            .frame(width: 70, height: 70)
            .stipple(seed: seed(facet.id))
            Text(facet.name).caption(8.5, on ? SF.paper : SF.mist)
                .lineLimit(1).minimumScaleFactor(0.6)
                .offset(y: -10)
        }
    }
}

// MARK: - Weigh: each interest is a star falling toward the world it belongs to.

struct InterestWeigher: View {
    @Binding var soul: Soul
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(soul.activeInterests, id: \.0.id) { f, w in
                InterestComet(facet: f, weight: w, limit: soul.interestLimit(f.id),
                              onChange: { soul.setInterest(f.id, $0) },
                              onAscend: { soul.ascend(f.id) })
            }
            let asc = soul.ascended.compactMap(Catalog.facet).sorted { $0.name < $1.name }
            if !asc.isEmpty {
                VStack(alignment: .leading, spacing: -10) {
                    ForEach(asc) { f in
                        HStack(spacing: 2) {
                            PlanetGlyph(colors: [f.element.color], radius: 6, spread: 0.9)
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                                .onTapGesture {
                                    withAnimation(.easeInOut) { soul.descend(f.id) }
                                    Resonator.shared.play(.snap)
                                }
                            Text("\(f.name)  →  \(Catalog.facet(f.root ?? "")?.name ?? "")").caption(9, SF.paper.opacity(0.75))
                        }
                    }
                }
                .padding(.top, 18)
            }
        }
    }
}

struct InterestComet: View {
    var facet: Facet
    var weight: Double
    var limit: Double
    var onChange: (Double) -> Void
    var onAscend: () -> Void

    @State private var over: CGFloat = 0

    var body: some View {
        HStack(spacing: 8) {
            Text(facet.name).caption(9, SF.paper.opacity(0.8))
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(width: 88, alignment: .leading)
            GeometryReader { geo in
                let w = geo.size.width
                let x0: CGFloat = 6, slotX = w - 20, trackW = slotX - 44
                let frac = CGFloat(weight / Soul.interestCeiling)
                let hx = x0 + trackW * frac + over * (slotX - x0 - trackW)
                let limX = x0 + trackW * CGFloat(limit / Soul.interestCeiling)
                Canvas { ctx, size in
                    let cy = size.height / 2
                    var rail = Path()
                    rail.move(to: CGPoint(x: x0, y: cy)); rail.addLine(to: CGPoint(x: slotX - 16, y: cy))
                    ctx.stroke(rail, with: .color(.white.opacity(0.09)), lineWidth: 1)
                    if limit < Soul.interestCeiling - 0.01 {
                        ctx.fill(Celestial.disk(CGPoint(x: limX, y: cy), 1.5), with: .color(.white.opacity(0.6)))
                    }
                    Celestial.planet(&ctx, center: CGPoint(x: slotX, y: cy), radius: 8, colors: [facet.element.color],
                                     intensity: 0.2 + 0.6 * Double(frac) + Double(over), light: .pi, spread: 0.85)
                    Celestial.comet(&ctx, head: CGPoint(x: hx, y: cy), angle: .pi, length: hx - x0 + 2, width: 2,
                                    intensity: 0.4 + 0.6 * Double(frac), headColor: facet.element.color)
                }
                .stipple(seed: seed(facet.id))
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 2)
                    .onChanged { g in
                        let x = g.location.x
                        let nw = min(max(0, Double((x - x0) / trackW) * Soul.interestCeiling), limit).rounded()
                        if Int(nw) != Int(weight) { Resonator.shared.tick() }
                        onChange(nw)
                        if limit >= Soul.interestCeiling - 0.01, x > x0 + trackW {
                            over = min(1, (x - x0 - trackW) / (slotX - x0 - trackW))
                        } else { over = 0 }
                    }
                    .onEnded { _ in
                        if over > 0.7 {
                            Resonator.shared.play(.ascend)
                            withAnimation(.easeInOut(duration: 0.6)) { onAscend() }
                        }
                        over = 0
                    })
            }
            .frame(height: 40)
        }
    }
}

// MARK: - Temper: a star leaving the centre toward one pole.

struct TraitsEditor: View {
    @Binding var soul: Soul
    var body: some View {
        VStack(spacing: 22) {
            ForEach(Catalog.traits) { p in
                TraitLine(polarity: p, value: soul.trait(p.id), tint: soul.hue) { soul.traits[p.id] = $0 }
            }
        }
    }
}

struct TraitLine: View {
    var polarity: Polarity
    var value: Double
    var tint: Color
    var onChange: (Double) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(polarity.left).caption(8.5, SF.paper.opacity(0.35 + 0.6 * max(0, -value)))
                .lineLimit(1).minimumScaleFactor(0.6).frame(width: 70, alignment: .trailing)
            GeometryReader { geo in
                let w = geo.size.width, pad: CGFloat = 10
                let mid = w / 2
                let x = pad + (w - 2 * pad) * CGFloat((value + 1) / 2)
                Canvas { ctx, size in
                    let cy = size.height / 2
                    for i in 0...8 {
                        let tx = pad + (w - 2 * pad) * CGFloat(i) / 8
                        ctx.fill(Celestial.disk(CGPoint(x: tx, y: cy), i % 4 == 0 ? 1.4 : 0.8), with: .color(.white.opacity(0.4)))
                    }
                    Celestial.comet(&ctx, head: CGPoint(x: x, y: cy), angle: value >= 0 ? .pi : 0, length: abs(x - mid),
                                    width: 2, intensity: 0.55 + 0.45 * abs(value), headColor: tint)
                }
                .stipple(seed: seed(polarity.id))
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 2).onChanged { g in
                    let raw = Double((g.location.x - pad) / (w - 2 * pad)) * 2 - 1
                    let v = (min(max(raw, -1), 1) * 8).rounded() / 8
                    if v != value { Resonator.shared.tick() }
                    onChange(v)
                })
            }
            .frame(height: 40)
            Text(polarity.right).caption(8.5, SF.paper.opacity(0.35 + 0.6 * max(0, value)))
                .lineLimit(1).minimumScaleFactor(0.6).frame(width: 70, alignment: .leading)
        }
    }
}

// MARK: - Hold: what your interests already feed, and what you add.

struct ValuesEditor: View {
    @Binding var soul: Soul
    var body: some View {
        VStack(spacing: 4) {
            ForEach(Catalog.values) { f in
                ValueComet(facet: f, direct: soul.valueWeight(f.id), under: soul.undercurrent(into: f.id),
                           limit: soul.valueLimit(f.id)) { soul.setValue(f.id, $0) }
            }
        }
    }
}

struct ValueComet: View {
    var facet: Facet
    var direct: Double
    var under: Double
    var limit: Double
    var onChange: (Double) -> Void
    static let scale = 70.0

    var body: some View {
        HStack(spacing: 8) {
            Text(facet.name).caption(9, SF.paper.opacity(0.8))
                .lineLimit(1).frame(width: 88, alignment: .leading)
            GeometryReader { geo in
                let x0: CGFloat = 8, tw = geo.size.width - 24
                let u = tw * CGFloat(min(under, Self.scale) / Self.scale)
                let d = tw * CGFloat(min(direct, Self.scale - under) / Self.scale)
                Canvas { ctx, size in
                    let cy = size.height / 2
                    var rail = Path()
                    rail.move(to: CGPoint(x: x0, y: cy)); rail.addLine(to: CGPoint(x: x0 + tw, y: cy))
                    ctx.stroke(rail, with: .color(.white.opacity(0.08)), lineWidth: 1)
                    if u > 0.5 {
                        Celestial.trail(&ctx, from: CGPoint(x: x0 + u, y: cy), to: CGPoint(x: x0, y: cy), width: 2,
                                        color: facet.element.color, intensity: 0.55)
                    }
                    let total = (under + direct) / Self.scale
                    Celestial.comet(&ctx, head: CGPoint(x: x0 + u + d, y: cy), angle: .pi, length: d, width: 2,
                                    intensity: 0.35 + 0.65 * min(1, total * 1.8), headColor: facet.element.color)
                }
                .stipple(seed: seed(facet.id))
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 2).onChanged { g in
                    let nd = Double((g.location.x - x0 - u) / tw) * Self.scale
                    let v = min(max(0, nd), limit).rounded()
                    if Int(v) != Int(direct) { Resonator.shared.tick() }
                    onChange(v)
                })
            }
            .frame(height: 36)
        }
    }
}

/// Remaining light: a thin ring and a number.
struct LightGauge: View {
    var remaining: Double
    var body: some View {
        ZStack {
            Circle().stroke(SF.faint, lineWidth: 1)
            Circle().trim(from: 0, to: remaining / Soul.bank)
                .stroke(SF.blue, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(remaining.rounded()))").font(SF.type(10)).monospacedDigit().foregroundStyle(SF.paper.opacity(0.85))
        }
        .frame(width: 30, height: 30)
    }
}
