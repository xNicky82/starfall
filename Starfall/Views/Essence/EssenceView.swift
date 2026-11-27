import SwiftUI

/// Your soul at a glance, and every realm editable in place.
struct EssenceView: View {
    @Environment(Store.self) private var store
    @State private var realm = 0
    @State private var confirmReset = false

    var body: some View {
        if let me = store.me {
            let binding = Binding<Soul>(get: { store.me ?? me }, set: { store.me = $0 })
            ZStack {
                SanctuaryBackground(glow: me.hue)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        Text("Essence").eyebrow(me.hue).padding(.top, 8)
                        OrbView(colors: me.auraColors).frame(width: 280, height: 280).padding(.vertical, -26)
                        Text(me.name).title(32)

                        HStack(spacing: 18) {
                            LightRing(spent: me.spent, size: 76)
                            VStack(alignment: .leading, spacing: 8) {
                                stat("Interests", me.activeInterests.reduce(0) { $0 + $1.1 })
                                stat("Ascended", me.ascended.reduce(0) { $0 + me.interestWeight($1) })
                                stat("Values", me.values.values.reduce(0, +))
                            }
                            Spacer()
                        }
                        .padding(18)
                        .background(RoundedRectangle(cornerRadius: 24).fill(SF.card))

                        ElementBar(soul: me)
                            .padding(18)
                            .background(RoundedRectangle(cornerRadius: 24).fill(SF.card))

                        RealmToggle(selection: $realm, tint: me.hue)

                        Group {
                            switch realm {
                            case 0: InterestWeigher(soul: binding)
                            case 1: TraitsEditor(soul: binding)
                            case 2: ValuesEditor(soul: binding)
                            default: InterestPicker(soul: binding)
                            }
                        }
                        .padding(18)
                        .background(RoundedRectangle(cornerRadius: 24).fill(SF.card))

                        ResonatorPanel()

                        VStack(spacing: 10) {
                            Text("Begin again").eyebrow()
                            SlotSlider(label: "slide to dissolve", tint: Element.ember.color) { store.reset() }
                        }
                        .padding(.top, 10)

                        Color.clear.frame(height: 110)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func stat(_ name: String, _ v: Double) -> some View {
        HStack {
            Text(name).font(SF.label(12)).foregroundStyle(SF.mist).frame(width: 74, alignment: .leading)
            Text("\(Int(v.rounded()))").font(SF.display(15)).monospacedDigit().foregroundStyle(SF.ink)
        }
    }
}

/// A sliding segmented toggle — the pill glides between realms.
struct RealmToggle: View {
    @Binding var selection: Int
    var tint: Color
    let items = ["Interests", "Traits", "Values", "Gather"]
    @Namespace private var ns

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width / CGFloat(items.count)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.5))
                Capsule().fill(tint).frame(width: w - 6).padding(3)
                    .offset(x: w * CGFloat(selection))
                    .shadow(color: tint.opacity(0.35), radius: 8)
                HStack(spacing: 0) {
                    ForEach(items.indices, id: \.self) { i in
                        Text(items[i]).font(SF.label(11)).tracking(1.5).textCase(.uppercase)
                            .foregroundStyle(i == selection ? .white : SF.mist)
                            .frame(width: w, height: 44)
                    }
                }
            }
            .contentShape(Capsule())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { g in
                    let i = min(items.count - 1, max(0, Int(g.location.x / w)))
                    if i != selection {
                        Resonator.shared.tick()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selection = i }
                    }
                })
        }
        .frame(height: 44)
    }
}

/// Hardware outputs + a place to feel each kind of meeting.
struct ResonatorPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Resonators").eyebrow()
            ForEach(Resonator.shared.outputs.indices, id: \.self) { i in
                let o = Resonator.shared.outputs[i]
                row(o.label, o.isAvailable ? "connected" : "unavailable here", on: o.isAvailable)
            }
            row("Starfall Pebble", "not yet forged", on: false)
            Text("Feel a meeting").eyebrow().padding(.top, 6)
            HStack(spacing: 22) {
                ForEach(Meeting.allCases, id: \.self) { m in
                    VStack(spacing: 8) {
                        Circle()
                            .fill(color(m))
                            .frame(width: 54, height: 54)
                            .shadow(color: color(m).opacity(0.5), radius: 10)
                            .contentShape(Circle())
                            .onTapGesture { Resonator.shared.play(.meeting(m)) }
                        Text(m.word).font(SF.label(10)).tracking(2).foregroundStyle(SF.mist)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24).fill(SF.card))
    }

    private func color(_ m: Meeting) -> Color {
        switch m { case .mend: return SF.blue; case .spark: return Element.sol.color; case .clash: return Element.ember.color }
    }
    private func row(_ name: String, _ status: String, on: Bool) -> some View {
        HStack(spacing: 12) {
            Circle().fill(on ? SF.blue : SF.faint).frame(width: 10, height: 10)
            Text(name).font(SF.display(15)).foregroundStyle(SF.ink)
            Spacer()
            Text(status).font(SF.body(12)).foregroundStyle(SF.mist)
        }
    }
}
