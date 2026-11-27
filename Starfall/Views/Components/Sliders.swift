import SwiftUI

// MARK: - Slot slider: slide the circle home to continue.

struct SlotSlider: View {
    var label: String
    var tint: Color = SF.blue
    var colors: [Color]? = nil
    var onSlot: () -> Void

    @State private var x: CGFloat = 0
    @State private var slotted = false
    private let h: CGFloat = 68, knob: CGFloat = 56

    var body: some View {
        GeometryReader { geo in
            let travel = geo.size.width - h
            let p = travel > 0 ? x / travel : 0
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.5))
                Capsule().stroke(SF.faint, lineWidth: 1)
                // trail of light
                Capsule().fill(LinearGradient(colors: [tint.opacity(0), tint.opacity(0.25)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: x + h)
                Text(label).eyebrow(SF.ink.opacity(0.55))
                    .frame(maxWidth: .infinity).opacity(1 - Double(p) * 1.6)
                // the slot
                Circle().strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [3, 4]))
                    .foregroundStyle(tint.opacity(0.5 + 0.5 * Double(p)))
                    .frame(width: knob + 4, height: knob + 4)
                    .offset(x: travel + (h - knob - 4) / 2)
                // the circle
                ZStack {
                    if let colors { OrbView(colors: colors).frame(width: knob * 2.3, height: knob * 2.3) }
                    else { Circle().fill(tint).shadow(color: tint.opacity(0.45), radius: 10) }
                }
                .frame(width: knob, height: knob)
                .offset(x: x + (h - knob) / 2)
                .scaleEffect(slotted ? 0.92 : 1)
            }
            .frame(height: h)
            .contentShape(Capsule())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { g in
                    guard !slotted else { return }
                    x = min(max(0, g.translation.width), travel)
                }
                .onEnded { _ in
                    guard !slotted else { return }
                    if x > travel * 0.82 {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { x = travel; slotted = true }
                        Resonator.shared.play(.snap)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            onSlot()
                            withAnimation(.easeOut(duration: 0.4)) { x = 0; slotted = false }
                        }
                    } else {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) { x = 0 }
                    }
                })
        }
        .frame(height: h)
    }
}

// MARK: - Dual slot: release to the left, bond to the right.

struct DualSlotSlider: View {
    var leftLabel: String
    var rightLabel: String
    var colors: [Color]
    var rightTint: Color
    var onLeft: () -> Void
    var onRight: () -> Void

    @State private var x: CGFloat = 0
    @State private var done = false
    private let h: CGFloat = 76, knob: CGFloat = 58

    var body: some View {
        GeometryReader { geo in
            let half = (geo.size.width - h) / 2
            let p = half > 0 ? x / half : 0
            ZStack {
                Capsule().fill(Color.white.opacity(0.5))
                Capsule().stroke(SF.faint, lineWidth: 1)
                HStack {
                    Text(leftLabel).eyebrow(SF.ink.opacity(0.5)).opacity(p < 0 ? 1 + Double(-p) : 1 - Double(p) * 1.5)
                    Spacer()
                    Text(rightLabel).eyebrow(rightTint).opacity(p > 0 ? 1 + Double(p) : 1 + Double(p) * 1.5)
                }
                .padding(.horizontal, h + 8)
                HStack {
                    Circle().strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [3, 4]))
                        .foregroundStyle(SF.ink.opacity(0.25 + 0.6 * Double(max(0, -p))))
                    Spacer()
                    Circle().strokeBorder(style: StrokeStyle(lineWidth: 1.4, dash: [3, 4]))
                        .foregroundStyle(rightTint.opacity(0.4 + 0.6 * Double(max(0, p))))
                }
                .frame(height: knob + 4)
                .padding(.horizontal, (h - knob - 4) / 2)
                OrbView(colors: colors).frame(width: knob * 2.3, height: knob * 2.3)
                    .frame(width: knob, height: knob)
                    .offset(x: x)
            }
            .frame(height: h)
            .contentShape(Capsule())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { g in
                    guard !done else { return }
                    let nx = min(max(-half, g.translation.width), half)
                    if Int(nx / 24) != Int(x / 24) { Resonator.shared.tick() }
                    x = nx
                }
                .onEnded { _ in
                    guard !done else { return }
                    if abs(x) > half * 0.8 {
                        let right = x > 0
                        done = true
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { x = right ? half : -half }
                        Resonator.shared.play(.snap)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { right ? onRight() : onLeft() }
                    } else {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) { x = 0 }
                    }
                })
        }
        .frame(height: h)
    }
}

// MARK: - Interest weight: slide to weigh, push into the slot to ascend.

struct InterestSlider: View {
    var facet: Facet
    var weight: Double
    var limit: Double
    var onChange: (Double) -> Void
    var onAscend: () -> Void

    @State private var dragX: CGFloat? = nil
    private let knob: CGFloat = 28, slot: CGFloat = 34, gap: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Glyph(element: facet.element, size: 10)
                Text(facet.name).font(SF.display(16)).foregroundStyle(SF.ink)
                Spacer()
                Text("\(Int(weight.rounded()))").font(SF.label(13)).monospacedDigit().foregroundStyle(SF.mist)
            }
            GeometryReader { geo in
                let trackW = geo.size.width - slot - gap
                let full = weight >= Soul.interestCeiling - 0.01
                let baseX = CGFloat(weight / Soul.interestCeiling) * trackW
                let kx = dragX ?? baseX
                let inSlot = kx > trackW + gap * 0.5
                ZStack(alignment: .leading) {
                    Capsule().fill(SF.faint).frame(width: trackW, height: 4)
                    // what the bank still allows
                    Capsule().fill(facet.element.color.opacity(0.12))
                        .frame(width: CGFloat(limit / Soul.interestCeiling) * trackW, height: 4)
                    Capsule().fill(facet.element.color).frame(width: min(kx, trackW), height: 4)
                    // ascension slot
                    ZStack {
                        Circle().strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [2.5, 3.5]))
                            .foregroundStyle(facet.element.color.opacity(full ? 0.9 : 0.25))
                        if let root = facet.root.flatMap(Catalog.facet) {
                            Text(String(root.name.prefix(1))).font(SF.label(11))
                                .foregroundStyle(facet.element.color.opacity(full ? 1 : 0.3))
                        }
                    }
                    .frame(width: slot, height: slot)
                    .scaleEffect(inSlot ? 1.25 : 1)
                    .offset(x: trackW + gap)
                    Circle().fill(.white)
                        .overlay(Circle().stroke(facet.element.color, lineWidth: 2))
                        .shadow(color: facet.element.color.opacity(0.35), radius: inSlot ? 10 : 4)
                        .frame(width: knob, height: knob)
                        .offset(x: (inSlot ? trackW + gap + (slot - knob) / 2 : min(kx, trackW)) - (inSlot ? 0 : knob / 2))
                }
                .frame(height: slot)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 1)
                    .onChanged { g in
                        let canReachSlot = limit >= Soul.interestCeiling - 0.01
                        let maxX = canReachSlot ? trackW + gap + slot : CGFloat(limit / Soul.interestCeiling) * trackW
                        let nx = min(max(0, g.location.x), maxX)
                        dragX = nx
                        let w = Double(min(nx, trackW) / trackW) * Soul.interestCeiling
                        if Int(w) != Int(weight) { Resonator.shared.tick() }
                        onChange(w.rounded())
                    }
                    .onEnded { _ in
                        if let d = dragX, d > trackW + gap * 0.5, limit >= Soul.interestCeiling - 0.01 {
                            onChange(Soul.interestCeiling)
                            Resonator.shared.play(.ascend)
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { onAscend() }
                        }
                        withAnimation(.spring(response: 0.3)) { dragX = nil }
                    })
            }
            .frame(height: slot)
        }
    }
}

// MARK: - Value weight: interests already flow in as an undercurrent.

struct ValueSlider: View {
    var facet: Facet
    var direct: Double
    var undercurrent: Double
    var limit: Double
    var feeders: [String]
    var onChange: (Double) -> Void

    static let scale: Double = 70
    @State private var dragging = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Glyph(element: facet.element, size: 10)
                Text(facet.name).font(SF.display(16)).foregroundStyle(SF.ink)
                Text(facet.line).font(SF.body(12)).foregroundStyle(SF.mist).lineLimit(1)
                Spacer()
                Text("\(Int((direct + undercurrent).rounded()))").font(SF.label(13)).monospacedDigit().foregroundStyle(SF.mist)
            }
            GeometryReader { geo in
                let w = geo.size.width
                let u = CGFloat(min(undercurrent, Self.scale) / Self.scale) * w
                let d = CGFloat(direct / Self.scale) * w
                let lim = CGFloat(limit / Self.scale) * w
                ZStack(alignment: .leading) {
                    Capsule().fill(SF.faint).frame(height: 4)
                    Capsule().fill(facet.element.color.opacity(0.12)).frame(width: min(w, u + lim), height: 4)
                    // undercurrent from interests — striped, you didn't choose it directly
                    Capsule().fill(facet.element.color.opacity(0.35)).frame(width: u, height: 4)
                    Capsule().fill(facet.element.color).frame(width: d, height: 4).offset(x: u)
                    Circle().fill(.white).overlay(Circle().stroke(facet.element.color, lineWidth: 2))
                        .shadow(color: facet.element.color.opacity(0.3), radius: dragging ? 8 : 3)
                        .frame(width: 26, height: 26)
                        .offset(x: min(u + d, w) - 13)
                }
                .frame(height: 30)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 1)
                    .onChanged { g in
                        dragging = true
                        let nd = Double(max(0, g.location.x - u) / w) * Self.scale
                        if Int(nd) != Int(direct) { Resonator.shared.tick() }
                        onChange(min(nd, limit).rounded())
                    }
                    .onEnded { _ in dragging = false })
            }
            .frame(height: 30)
            if !feeders.isEmpty {
                Text("fed by " + feeders.joined(separator: " · ")).font(SF.body(11)).foregroundStyle(facet.element.color)
            }
        }
    }
}

// MARK: - Trait polarity

struct PolaritySlider: View {
    var polarity: Polarity
    var value: Double
    var tint: Color = SF.blue
    var onChange: (Double) -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(polarity.left).font(SF.display(15)).foregroundStyle(SF.ink.opacity(0.45 + 0.55 * max(0, -value)))
                Spacer()
                Text(polarity.right).font(SF.display(15)).foregroundStyle(SF.ink.opacity(0.45 + 0.55 * max(0, value)))
            }
            GeometryReader { geo in
                let w = geo.size.width
                let x = CGFloat((value + 1) / 2) * w
                ZStack(alignment: .leading) {
                    Rectangle().fill(SF.faint).frame(height: 1)
                    ForEach(0..<9) { i in
                        Rectangle().fill(SF.ink.opacity(i % 4 == 0 ? 0.3 : 0.12))
                            .frame(width: 1, height: i % 4 == 0 ? 12 : 6)
                            .offset(x: w * CGFloat(i) / 8)
                    }
                    Rectangle().fill(tint).frame(width: abs(x - w / 2), height: 2)
                        .offset(x: min(x, w / 2))
                    Circle().fill(tint).frame(width: 24, height: 24)
                        .shadow(color: tint.opacity(0.4), radius: 6)
                        .offset(x: x - 12)
                }
                .frame(height: 30)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 1).onChanged { g in
                    let raw = Double(g.location.x / w) * 2 - 1
                    let v = (min(max(raw, -1), 1) * 8).rounded() / 8
                    if v != value { Resonator.shared.tick() }
                    onChange(v)
                })
            }
            .frame(height: 30)
        }
    }
}

// MARK: - The light ring: how much of your bank is left.

struct LightRing: View {
    var spent: Double
    var size: CGFloat = 64
    var body: some View {
        let p = min(1, spent / Soul.bank)
        ZStack {
            Circle().stroke(SF.faint, lineWidth: 5)
            Circle().trim(from: 0, to: p)
                .stroke(SF.blue, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.4), value: p)
            VStack(spacing: 0) {
                Text("\(Int((Soul.bank - spent).rounded()))").font(SF.display(size * 0.3)).monospacedDigit().foregroundStyle(SF.ink)
                Text("light").font(SF.label(size * 0.13)).tracking(1.5).foregroundStyle(SF.mist)
            }
        }
        .frame(width: size, height: size)
    }
}
