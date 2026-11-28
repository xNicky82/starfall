import SwiftUI

/// Onboarding, inside the field. Your orb sits at the top and recolours as you make it.
/// Name → nature → interests → light → values, then the tab bar arrives and you're on Home.
struct AttuneLayer: View {
    let orbit: Orbit
    @Environment(Store.self) private var store
    @State private var step = UserDefaults.standard.string(forKey: "attuneStep").flatMap(Int.init) ?? 0 // launch arg for screenshots
    @State private var open: String?
    @FocusState private var nameFocused: Bool

    private static let steps: [(title: String, note: String)] = [
        ("Welcome", "What should people call you?"),
        ("Your nature", "Where you sit picks your colours."),
        ("Interests", "Pick what you love."),
        ("Your light", "Loving one thing costs another."),
        ("Values", "What you hold."),
    ]

    var body: some View {
        if let me = store.me {
            let soul = Binding<Soul>(get: { store.me ?? me }, set: { store.me = $0 })
            let s = Self.steps[step]
            VStack(spacing: 0) {
                OrbitHeader(orbit: orbit, title: s.title, subtitle: s.note) {
                    if step > 0 {
                        Button { go(step - 1) } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(OrbPalette.ink)
                                .frame(width: 42, height: 42)
                                .glassCapsule()
                        }
                        .buttonStyle(.plain)
                    }
                }
                ScrollView(showsIndicators: false) {
                    content(me, soul)
                        .foregroundStyle(OrbPalette.ink)
                        .padding(.horizontal, 20)
                        .padding(.top, max(0, orbit.profilePanelTop - (orbit.insets.top + 76)))
                        .padding(.bottom, 130)
                        .frame(maxWidth: 520)
                        .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .frame(width: orbit.size.width, height: orbit.size.height, alignment: .top)
            .overlay(alignment: .bottom) {
                VStack(spacing: 12) {
                    HStack(spacing: 7) {
                        ForEach(0..<Self.steps.count, id: \.self) { i in
                            Capsule().fill(i == step ? OrbPalette.ink : OrbPalette.ink.opacity(0.18))
                                .frame(width: i == step ? 18 : 6, height: 6)
                        }
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: step)
                    SlideToEnter(label: step == Self.steps.count - 1 ? "Enter Starfall" : "Continue",
                                 colors: me.auraColors, enabled: canContinue(me)) { advance() }
                }
                .frame(maxWidth: 440)
                .padding(.horizontal, max(16, orbit.insets.leading))
                .padding(.top, 36)
                .padding(.bottom, orbit.keyboard > 0 ? orbit.keyboard + 12 : orbit.insets.bottom + 10)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(stops: [.init(color: OrbPalette.ground.opacity(0), location: 0),
                                           .init(color: OrbPalette.ground, location: 0.45)],
                                   startPoint: .top, endPoint: .bottom)
                        .allowsHitTesting(false))
            }
            .onChange(of: store.me) { _, _ in orbit.refreshMe() }
            .onAppear { if step == 0 && me.name.isEmpty { DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { nameFocused = true } } }
        }
    }

    @ViewBuilder
    private func content(_ me: Soul, _ soul: Binding<Soul>) -> some View {
        switch step {
        case 0:
            VStack(spacing: 10) {
                TextField("", text: soul.name, prompt: Text("Your name").foregroundStyle(OrbPalette.muted.opacity(0.6)))
                    .font(.system(size: 28, weight: .bold)).tracking(-0.4)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.words).autocorrectionDisabled()
                    .submitLabel(.continue)
                    .focused($nameFocused)
                    .onSubmit { if canContinue(me) { advance() } }
                Rectangle().fill(OrbPalette.ink.opacity(0.15)).frame(width: 180, height: 1)
            }
            .padding(.top, 10)
        case 1:
            VStack(spacing: 18) {
                ForEach(Catalog.traits) { p in
                    NatureSlider(polarity: p, value: me.trait(p.id)) { soul.wrappedValue.traits[p.id] = $0 }
                }
            }
        case 2:
            VStack(alignment: .leading, spacing: 22) {
                ForEach(Catalog.values) { v in
                    let items = Catalog.interests(rootedIn: v.id)
                    if !items.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(v.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(OrbPalette.muted)
                            FlowLayout(spacing: 7) {
                                ForEach(items) { f in chip(f, on: me.interests[f.id] != nil) { soul.wrappedValue.toggleInterest(f.id) } }
                            }
                        }
                    }
                }
            }
        case 3:
            VStack(spacing: 10) {
                lightLeft(me)
                let ids = me.interests.keys.sorted { (Catalog.facet($0)?.name ?? "") < (Catalog.facet($1)?.name ?? "") }
                ForEach(ids, id: \.self) { id in
                    if let f = Catalog.facet(id) {
                        InterestCard(facet: f, soul: soul, open: open == id) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { open = open == id ? nil : id }
                        }
                    }
                }
            }
        default:
            VStack(spacing: 12) {
                lightLeft(me)
                ForEach(Catalog.values) { f in
                    ValueBar(facet: f, direct: me.valueWeight(f.id), under: me.undercurrent(into: f.id),
                             limit: me.valueLimit(f.id)) { soul.wrappedValue.setValue(f.id, $0) }
                }
            }
        }
    }

    private func chip(_ f: Facet, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Resonator.shared.play(.tick)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { action() }
        } label: {
            HStack(spacing: 7) {
                Circle().fill(on ? OrbPalette.paper : f.element.color).frame(width: 7, height: 7)
                Text(f.name).font(.system(size: 14.5, weight: .medium))
            }
            .foregroundStyle(on ? OrbPalette.paper : OrbPalette.ink)
            .padding(.horizontal, 13).padding(.vertical, 9)
            .background(on ? f.element.color : Color.white.opacity(0.6), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func lightLeft(_ me: Soul) -> some View {
        HStack(spacing: 10) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(OrbPalette.ink.opacity(0.07))
                    Capsule().fill(OrbPalette.ink).frame(width: g.size.width * CGFloat(me.remaining / Soul.bank))
                }
            }
            .frame(height: 6)
            Text("\(Int(me.remaining.rounded())) light left")
                .font(.system(size: 13, weight: .medium)).monospacedDigit().foregroundStyle(OrbPalette.muted)
                .fixedSize()
        }
        .padding(.bottom, 8)
        .animation(.easeOut(duration: 0.2), value: me.remaining)
    }

    private func canContinue(_ me: Soul) -> Bool {
        switch step {
        case 0: return !me.name.trimmingCharacters(in: .whitespaces).isEmpty
        case 2: return me.interests.count >= 2
        default: return true
        }
    }

    private func go(_ s: Int) {
        nameFocused = false
        open = nil
        withAnimation(.easeInOut(duration: 0.35)) { step = max(0, min(Self.steps.count - 1, s)) }
    }

    private func advance() {
        if step == 0, var m = store.me { m.name = m.name.trimmingCharacters(in: .whitespaces); store.me = m }
        if step == Self.steps.count - 1 {
            nameFocused = false
            withAnimation(.easeInOut(duration: 0.6)) { orbit.finishAttune() }
        } else {
            go(step + 1)
        }
    }
}

/// Slide your orb into the slot. The only way forward.
struct SlideToEnter: View {
    let label: String
    let colors: [Color]
    var enabled = true
    let onSlot: () -> Void

    @State private var x: CGFloat = 0
    @State private var done = false
    private let h: CGFloat = 62, knob: CGFloat = 50

    var body: some View {
        GeometryReader { g in
            let travel = g.size.width - h
            let p = travel > 0 ? x / travel : 0
            ZStack(alignment: .leading) {
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(OrbPalette.ink.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .opacity(1 - Double(p) * 1.8)
                Circle()
                    .strokeBorder(OrbPalette.ink.opacity(0.25 + 0.6 * Double(p)), style: StrokeStyle(lineWidth: 1.2, dash: [3, 4]))
                    .frame(width: knob + 4, height: knob + 4)
                    .offset(x: travel + (h - knob - 4) / 2)
                ZStack {
                    // energy bands peeking out behind the orb, like in the field
                    ForEach(Array(colors.prefix(3).enumerated()), id: \.offset) { i, c in
                        Circle().fill(c).offset(x: -CGFloat(i + 1) * (2 + 6 * p))
                    }
                    .opacity(enabled ? 1 : 0)
                    Circle().fill(OrbPalette.ink)
                }
                .frame(width: knob, height: knob)
                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                .offset(x: x + (h - knob) / 2)
            }
            .frame(height: h)
            .glassCapsule()
            .contentShape(Capsule())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    guard enabled, !done else { return }
                    let nx = min(max(0, v.translation.width), travel)
                    if Int(nx / 28) != Int(x / 28) { Resonator.shared.tick() }
                    x = nx
                }
                .onEnded { _ in
                    guard enabled, !done else { return }
                    if x > travel * 0.85 {
                        done = true
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) { x = travel }
                        Resonator.shared.play(.snap)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onSlot()
                            withAnimation(.easeOut(duration: 0.4)) { x = 0 }
                            done = false
                        }
                    } else {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { x = 0 }
                    }
                })
            .opacity(enabled ? 1 : 0.55)
            .animation(.easeOut(duration: 0.2), value: enabled)
        }
        .frame(height: h)
    }
}
