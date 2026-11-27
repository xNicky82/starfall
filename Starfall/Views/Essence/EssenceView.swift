import SwiftUI

struct EssenceView: View {
    @Environment(Store.self) private var store
    @State private var realm = 0
    @State private var dissolve = 0.0

    var body: some View {
        if let me = store.me {
            let soul = Binding<Soul>(get: { store.me ?? me }, set: { store.me = $0 })
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    portrait(me)
                    RealmToggle(selection: $realm)
                    Group {
                        switch realm {
                        case 0: VStack(spacing: 30) { InterestWeigher(soul: soul); InterestField(soul: soul) }
                        case 1: TraitsEditor(soul: soul)
                        default: ValuesEditor(soul: soul)
                        }
                    }
                    .padding(.horizontal, 16)
                    feel
                    dissolveRing
                    Color.clear.frame(height: 110)
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(Sky())
        }
    }

    private func portrait(_ me: Soul) -> some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let R = w * 0.56, horizon = h * 0.6
            ZStack {
                TimelineView(.animation) { tl in
                    Canvas { ctx, _ in
                        let t = tl.date.timeIntervalSinceReferenceDate
                        Celestial.planet(&ctx, center: CGPoint(x: w / 2, y: horizon + R), radius: R, colors: me.auraColors,
                                         intensity: 1 + 0.06 * sin(t * 0.7), light: -.pi / 2 + 0.15 * sin(t * 0.2), spread: 1.2)
                    }
                }
                .stipple(specks: 0.002)
                Text(me.name).caption(15, SF.paper)
                    .position(x: w / 2, y: horizon + 54)
                LightGauge(remaining: me.remaining)
                    .position(x: w - 36, y: 74)
            }
        }
        .frame(height: 430)
    }

    private var feel: some View {
        HStack(spacing: 18) {
            ForEach(Meeting.allCases, id: \.self) { m in
                VStack(spacing: -6) {
                    PlanetGlyph(colors: [color(m)], radius: 8, spread: 1)
                        .contentShape(Circle())
                        .onTapGesture { Resonator.shared.play(.meeting(m)) }
                    Text(m.rawValue).caption(8, SF.mist)
                }
            }
        }
        .padding(.top, 10)
    }

    private var dissolveRing: some View {
        ZStack {
            Circle().stroke(SF.faint, lineWidth: 1)
            Circle().trim(from: 0, to: dissolve)
                .stroke(Element.ember.color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 26, height: 26)
        .contentShape(Circle())
        .onLongPressGesture(minimumDuration: 1.4, pressing: { p in
            withAnimation(p ? .linear(duration: 1.4) : .easeOut(duration: 0.25)) { dissolve = p ? 1 : 0 }
        }) {
            Resonator.shared.play(.clash)
            store.reset()
        }
        .padding(.top, 20)
    }

    private func color(_ m: Meeting) -> Color {
        switch m { case .mend: return SF.blue; case .spark: return Element.sol.color; case .clash: return Element.ember.color }
    }
}

/// Three words; a small star slides beneath the chosen one.
struct RealmToggle: View {
    @Binding var selection: Int
    private let items = ["interests", "traits", "values"]

    var body: some View {
        GeometryReader { g in
            let w = g.size.width / CGFloat(items.count)
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(items.indices, id: \.self) { i in
                        Text(items[i]).caption(9.5, i == selection ? SF.paper : SF.mist).frame(width: w, height: 22)
                    }
                }
                Canvas { ctx, s in
                    Celestial.star(&ctx, at: CGPoint(x: s.width / 2, y: s.height / 2), radius: 10, color: SF.blue)
                }
                .frame(width: 30, height: 30)
                .stipple()
                .offset(x: w * CGFloat(selection) + w / 2 - 15, y: 18)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                let i = min(items.count - 1, max(0, Int(v.location.x / w)))
                if i != selection {
                    Resonator.shared.tick()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selection = i }
                }
            })
        }
        .frame(height: 48)
        .padding(.horizontal, 20)
    }
}
