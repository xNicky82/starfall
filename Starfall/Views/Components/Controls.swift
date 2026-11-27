import SwiftUI

// MARK: - Slot: slide the dot into the ring.

struct SlotSlider: View {
    var enabled = true
    var onSlot: () -> Void

    @State private var x: CGFloat = 0
    @State private var slotted = false
    private let knob: CGFloat = 22, slot: CGFloat = 30

    var body: some View {
        GeometryReader { g in
            let travel = g.size.width - slot
            let p = travel > 0 ? x / travel : 0
            ZStack(alignment: .leading) {
                Rectangle().fill(SF.hair).frame(height: SF.line)
                    .padding(.leading, knob / 2).padding(.trailing, slot)
                Rectangle().fill(SF.blue).frame(width: x, height: SF.line).padding(.leading, knob / 2)
                Circle().strokeBorder(SF.blue.opacity(0.35 + 0.65 * Double(p)),
                                      style: StrokeStyle(lineWidth: SF.line, dash: [2, 3]))
                    .frame(width: slot, height: slot)
                    .offset(x: travel)
                ZStack {
                    Circle().fill(enabled ? SF.blue : SF.hair)
                    Circle().stroke(SF.blue.opacity(enabled ? 0.35 : 0), lineWidth: SF.line).padding(-5)
                }
                .frame(width: knob, height: knob)
                .offset(x: x + (slot - knob) / 2 - (slot - knob) / 2 * (1 - p))
            }
            .frame(height: slot + 10)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    guard enabled, !slotted else { return }
                    x = min(max(0, v.translation.width), travel)
                }
                .onEnded { _ in
                    guard enabled, !slotted else { return }
                    if x > travel * 0.85 {
                        slotted = true
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) { x = travel }
                        Resonator.shared.play(.snap)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onSlot()
                            withAnimation(.easeOut(duration: 0.4)) { x = 0 }
                            slotted = false
                        }
                    } else {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { x = 0 }
                    }
                })
        }
        .frame(height: 40)
        .opacity(enabled ? 1 : 0.45)
    }
}

// MARK: - Dual slot: drift on (one ring) ← dot → bond (two rings).

struct DualSlot: View {
    var onLeft: () -> Void
    var onRight: () -> Void

    @State private var x: CGFloat = 0
    @State private var done = false
    private let knob: CGFloat = 22, slot: CGFloat = 30

    var body: some View {
        GeometryReader { g in
            let half = (g.size.width - slot) / 2
            let p = half > 0 ? x / half : 0
            ZStack {
                Rectangle().fill(SF.hair).frame(height: SF.line).padding(.horizontal, slot)
                HStack {
                    Circle().strokeBorder(SF.ink.opacity(0.25 + 0.6 * Double(max(0, -p))), lineWidth: SF.line)
                        .frame(width: slot, height: slot)
                    Spacer()
                    ZStack {
                        Circle().strokeBorder(SF.blue.opacity(0.4 + 0.6 * Double(max(0, p))), lineWidth: SF.line).offset(x: -5)
                        Circle().strokeBorder(SF.blue.opacity(0.4 + 0.6 * Double(max(0, p))), lineWidth: SF.line).offset(x: 5)
                    }
                    .frame(width: slot, height: slot)
                }
                ZStack {
                    Circle().fill(SF.blue)
                    Circle().stroke(SF.blue.opacity(0.35), lineWidth: SF.line).padding(-5)
                }
                .frame(width: knob, height: knob)
                .offset(x: x)
            }
            .frame(height: slot + 10)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    guard !done else { return }
                    let nx = min(max(-half, v.translation.width), half)
                    if Int(nx / 22) != Int(x / 22) { Resonator.shared.tick() }
                    x = nx
                }
                .onEnded { _ in
                    guard !done else { return }
                    if abs(x) > half * 0.82 {
                        done = true
                        let right = x > 0
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) { x = right ? half : -half }
                        Resonator.shared.play(.snap)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { right ? onRight() : onLeft() }
                    } else {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { x = 0 }
                    }
                })
        }
        .frame(height: 40)
    }
}

// MARK: - Gather

struct InterestPicker: View {
    @Binding var soul: Soul
    private let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        LazyVGrid(columns: cols, spacing: 18) {
            ForEach(Catalog.interests) { f in
                let on = soul.interests[f.id] != nil
                VStack(spacing: 8) {
                    Canvas { ctx, s in
                        let c = CGPoint(x: s.width / 2, y: s.height / 2)
                        if on {
                            Rings.draw(&ctx, at: c, count: 4, gap: 4.5, inner: 3, seed: hashSeed(f.id))
                            ctx.fill(ring(c, 2), with: .color(SF.blue))
                        } else {
                            ctx.stroke(ring(c, 12), with: .color(SF.hair), lineWidth: SF.line)
                        }
                    }
                    .frame(width: 44, height: 44)
                    Text(f.name.lowercased()).label(9, on ? SF.ink : SF.mist).lineLimit(1).minimumScaleFactor(0.7)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) { soul.toggleInterest(f.id) }
                    Resonator.shared.play(.snap)
                }
            }
        }
    }
}

// MARK: - Weigh: rings grow with weight; push into the dotted slot to ascend.

struct InterestWeigher: View {
    @Binding var soul: Soul
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(soul.activeInterests, id: \.0.id) { f, w in
                WeightRow(facet: f, weight: w, limit: soul.interestLimit(f.id),
                          onChange: { soul.setInterest(f.id, $0) },
                          onAscend: { withAnimation(.easeInOut(duration: 0.4)) { soul.ascend(f.id) } })
            }
            let asc = soul.ascended.compactMap(Catalog.facet).sorted { $0.name < $1.name }
            if !asc.isEmpty {
                Rectangle().fill(SF.hair).frame(height: SF.line).padding(.vertical, 10)
                ForEach(asc) { f in
                    HStack(spacing: 12) {
                        Circle().fill(SF.blue).frame(width: 8, height: 8)
                            .padding(10).contentShape(Circle())
                            .onTapGesture {
                                withAnimation(.easeInOut) { soul.descend(f.id) }
                                Resonator.shared.play(.snap)
                            }
                        Text("\(f.name.lowercased()) → \(Catalog.facet(f.root ?? "")?.name.lowercased() ?? "")").label(10, SF.ink)
                    }
                }
            }
        }
    }
}

struct WeightRow: View {
    var facet: Facet
    var weight: Double
    var limit: Double
    var onChange: (Double) -> Void
    var onAscend: () -> Void
    @State private var over: CGFloat = 0

    var body: some View {
        HStack(spacing: 10) {
            Text(facet.name.lowercased()).label(10).lineLimit(1).minimumScaleFactor(0.7).frame(width: 86, alignment: .leading)
            GeometryReader { g in
                let w = g.size.width
                let slotX = w - 16, x0: CGFloat = 14, trackW = slotX - 30 - x0
                let frac = CGFloat(weight / Soul.interestCeiling)
                let kx = x0 + trackW * frac + over * (slotX - x0 - trackW)
                Canvas { ctx, s in
                    let cy = s.height / 2
                    var rail = Path(); rail.move(to: CGPoint(x: x0, y: cy)); rail.addLine(to: CGPoint(x: x0 + trackW, y: cy))
                    ctx.stroke(rail, with: .color(SF.hair), lineWidth: SF.line)
                    var fill = Path(); fill.move(to: CGPoint(x: x0, y: cy)); fill.addLine(to: CGPoint(x: kx, y: cy))
                    ctx.stroke(fill, with: .color(SF.blue), lineWidth: SF.line)
                    if limit < Soul.interestCeiling - 0.01 {
                        let lx = x0 + trackW * CGFloat(limit / Soul.interestCeiling)
                        var tk = Path(); tk.move(to: CGPoint(x: lx, y: cy - 4)); tk.addLine(to: CGPoint(x: lx, y: cy + 4))
                        ctx.stroke(tk, with: .color(SF.mist), lineWidth: SF.line)
                    }
                    ctx.stroke(ring(CGPoint(x: slotX, y: cy), 11), with: .color(SF.blue.opacity(frac >= 1 ? 0.9 : 0.3)),
                               style: StrokeStyle(lineWidth: SF.line, dash: [2, 3]))
                    Rings.draw(&ctx, at: CGPoint(x: kx, y: cy), count: 1 + Int(weight / 5), gap: 3, inner: 3,
                               seed: hashSeed(facet.id))
                    ctx.fill(ring(CGPoint(x: kx, y: cy), 2), with: .color(SF.blue))
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 2)
                    .onChanged { v in
                        let nw = min(max(0, Double((v.location.x - x0) / trackW) * Soul.interestCeiling), limit).rounded()
                        if Int(nw) != Int(weight) { Resonator.shared.tick() }
                        onChange(nw)
                        if limit >= Soul.interestCeiling - 0.01, v.location.x > x0 + trackW {
                            over = min(1, (v.location.x - x0 - trackW) / (slotX - x0 - trackW))
                        } else { over = 0 }
                    }
                    .onEnded { _ in
                        if over > 0.7 { Resonator.shared.play(.ascend); onAscend() }
                        withAnimation(.spring(response: 0.3)) { over = 0 }
                    })
            }
            .frame(height: 40)
        }
    }
}

// MARK: - Temper

struct TraitsEditor: View {
    @Binding var soul: Soul
    var body: some View {
        VStack(spacing: 14) {
            ForEach(Catalog.traits) { p in
                TraitRow(polarity: p, value: soul.trait(p.id)) { soul.traits[p.id] = $0 }
            }
        }
    }
}

struct TraitRow: View {
    var polarity: Polarity
    var value: Double
    var onChange: (Double) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(polarity.left.lowercased()).label(9, value < 0 ? SF.ink : SF.mist).frame(width: 68, alignment: .trailing)
            GeometryReader { g in
                let w = g.size.width, pad: CGFloat = 8
                let x = pad + (w - 2 * pad) * CGFloat((value + 1) / 2)
                Canvas { ctx, s in
                    let cy = s.height / 2
                    var axis = Path(); axis.move(to: CGPoint(x: pad, y: cy)); axis.addLine(to: CGPoint(x: w - pad, y: cy))
                    ctx.stroke(axis, with: .color(SF.hair), lineWidth: SF.line)
                    for i in 0...8 {
                        let tx = pad + (w - 2 * pad) * CGFloat(i) / 8, h: CGFloat = i % 4 == 0 ? 5 : 2.5
                        var tk = Path(); tk.move(to: CGPoint(x: tx, y: cy - h)); tk.addLine(to: CGPoint(x: tx, y: cy + h))
                        ctx.stroke(tk, with: .color(SF.hair), lineWidth: SF.line)
                    }
                    var seg = Path(); seg.move(to: CGPoint(x: w / 2, y: cy)); seg.addLine(to: CGPoint(x: x, y: cy))
                    ctx.stroke(seg, with: .color(SF.blue), lineWidth: 1.2)
                    ctx.stroke(ring(CGPoint(x: x, y: cy), 7), with: .color(SF.blue), lineWidth: SF.line)
                    ctx.fill(ring(CGPoint(x: x, y: cy), 2), with: .color(SF.blue))
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 1).onChanged { v in
                    let raw = Double((v.location.x - pad) / (w - 2 * pad)) * 2 - 1
                    let nv = (min(max(raw, -1), 1) * 8).rounded() / 8
                    if nv != value { Resonator.shared.tick() }
                    onChange(nv)
                })
            }
            .frame(height: 36)
            Text(polarity.right.lowercased()).label(9, value > 0 ? SF.ink : SF.mist).frame(width: 68, alignment: .leading)
        }
    }
}

// MARK: - Hold: dashed = what your interests already feed; solid = what you give.

struct ValuesEditor: View {
    @Binding var soul: Soul
    var body: some View {
        VStack(spacing: 6) {
            ForEach(Catalog.values) { f in
                ValueRow(facet: f, direct: soul.valueWeight(f.id), under: soul.undercurrent(into: f.id),
                         limit: soul.valueLimit(f.id)) { soul.setValue(f.id, $0) }
            }
        }
    }
}

struct ValueRow: View {
    var facet: Facet
    var direct: Double
    var under: Double
    var limit: Double
    var onChange: (Double) -> Void
    static let scale = 70.0

    var body: some View {
        HStack(spacing: 10) {
            Text(facet.name.lowercased()).label(10).frame(width: 86, alignment: .leading)
            GeometryReader { g in
                let x0: CGFloat = 4, tw = g.size.width - 14
                let u = tw * CGFloat(min(under, Self.scale) / Self.scale)
                let d = tw * CGFloat(min(direct, Self.scale - under) / Self.scale)
                Canvas { ctx, s in
                    let cy = s.height / 2
                    var rail = Path(); rail.move(to: CGPoint(x: x0, y: cy)); rail.addLine(to: CGPoint(x: x0 + tw, y: cy))
                    ctx.stroke(rail, with: .color(SF.hair), lineWidth: SF.line)
                    var up = Path(); up.move(to: CGPoint(x: x0, y: cy)); up.addLine(to: CGPoint(x: x0 + u, y: cy))
                    ctx.stroke(up, with: .color(SF.blue), style: StrokeStyle(lineWidth: 1.2, dash: [2, 2.5]))
                    var dp = Path(); dp.move(to: CGPoint(x: x0 + u, y: cy)); dp.addLine(to: CGPoint(x: x0 + u + d, y: cy))
                    ctx.stroke(dp, with: .color(SF.blue), lineWidth: 1.2)
                    let kc = CGPoint(x: x0 + u + d, y: cy)
                    ctx.stroke(ring(kc, 7), with: .color(SF.blue), lineWidth: SF.line)
                    ctx.fill(ring(kc, 2), with: .color(SF.blue))
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 1).onChanged { v in
                    let nd = min(max(0, Double((v.location.x - x0 - u) / tw) * Self.scale), limit).rounded()
                    if Int(nd) != Int(direct) { Resonator.shared.tick() }
                    onChange(nd)
                })
            }
            .frame(height: 34)
        }
    }
}

// MARK: - Small instruments

struct LightGauge: View {
    var remaining: Double
    var body: some View {
        ZStack {
            Circle().stroke(SF.hair, lineWidth: SF.line)
            Circle().trim(from: 0, to: remaining / Soul.bank)
                .stroke(SF.blue, style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(remaining.rounded()))").label(9).monospacedDigit()
        }
        .frame(width: 30, height: 30)
    }
}

struct RealmToggle: View {
    @Binding var selection: Int
    let items: [String]

    var body: some View {
        GeometryReader { g in
            let w = g.size.width / CGFloat(items.count)
            ZStack(alignment: .topLeading) {
                Rectangle().fill(SF.hair).frame(height: SF.line).offset(y: 30)
                Rectangle().fill(SF.blue).frame(width: w * 0.5, height: 1.2)
                    .offset(x: w * CGFloat(selection) + w * 0.25, y: 30)
                HStack(spacing: 0) {
                    ForEach(items.indices, id: \.self) { i in
                        Text(items[i]).label(10, i == selection ? SF.ink : SF.mist).frame(width: w, height: 26)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                let i = min(items.count - 1, max(0, Int(v.location.x / w)))
                if i != selection {
                    Resonator.shared.tick()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selection = i }
                }
            })
        }
        .frame(height: 34)
    }
}
