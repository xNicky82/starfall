import SwiftUI

struct EssenceView: View {
    @Environment(Store.self) private var store
    @State private var realm = 0
    @State private var dissolve = 0.0

    var body: some View {
        if let me = store.me {
            let soul = Binding<Soul>(get: { store.me ?? me }, set: { store.me = $0 })
            let q = me.lorenz
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    HStack {
                        Text(me.name.lowercased()).label(13)
                        Spacer()
                        LightGauge(remaining: me.remaining)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 8)

                    AttractorView(params: q, steps: 4000, spin: 0.05, axes: true)
                        .frame(height: 360)
                        .padding(.horizontal, 12)

                    Text(String(format: "σ %.1f   ρ %.1f   β %.2f", q.sigma, q.rho, q.beta)).label(9, SF.mist)

                    RealmToggle(selection: $realm, items: ["interests", "traits", "values"])
                        .padding(.horizontal, 22)
                        .padding(.top, 8)

                    Group {
                        switch realm {
                        case 0: VStack(spacing: 34) { InterestWeigher(soul: soul); InterestPicker(soul: soul) }
                        case 1: TraitsEditor(soul: soul)
                        default: ValuesEditor(soul: soul)
                        }
                    }
                    .padding(.horizontal, 20)

                    Rectangle().fill(SF.hair).frame(height: SF.line).padding(.horizontal, 22).padding(.top, 10)
                    feel
                    dissolveRing
                    Color.clear.frame(height: 100)
                }
            }
            .background(Paper())
        }
    }

    /// Feel each meeting: two rings overlapping, touching, apart.
    private var feel: some View {
        HStack(spacing: 44) {
            ForEach(Meeting.allCases, id: \.self) { m in
                let gap: CGFloat = m == .mend ? 6 : m == .spark ? 12 : 20
                ZStack {
                    Circle().stroke(SF.blue, lineWidth: SF.line).frame(width: 18, height: 18).offset(x: -gap / 2)
                    Circle().stroke(SF.ink.opacity(0.6), lineWidth: SF.line).frame(width: 18, height: 18).offset(x: gap / 2)
                }
                .frame(width: 48, height: 48)
                .contentShape(Circle())
                .onTapGesture { Resonator.shared.play(.meeting(m)) }
            }
        }
    }

    private var dissolveRing: some View {
        ZStack {
            Circle().stroke(SF.hair, lineWidth: SF.line)
            Circle().trim(from: 0, to: dissolve)
                .stroke(SF.ink, style: StrokeStyle(lineWidth: 1, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 22, height: 22)
        .padding(10)
        .contentShape(Circle())
        .onLongPressGesture(minimumDuration: 1.4, pressing: { p in
            withAnimation(p ? .linear(duration: 1.4) : .easeOut(duration: 0.25)) { dissolve = p ? 1 : 0 }
        }) {
            Resonator.shared.play(.clash)
            store.reset()
        }
        .padding(.top, 14)
    }
}
