import SwiftUI

/// Profile: your orb fanned open at the top, then everything it is made of, all editable in place.
/// Every edit writes to `store.me`, and the orb above recolours live.
struct ProfileLayer: View {
    @Bindable var orbit: Orbit
    @Environment(Store.self) private var store
    @State private var adding = false
    @State private var open: String?

    var body: some View {
        if let me = store.me {
            let soul = Binding<Soul>(get: { store.me ?? me }, set: { store.me = $0 })
            VStack(spacing: 0) {
                OrbitHeader(orbit: orbit, title: "Profile", subtitle: "How you show up to others") {
                    Button { orbit.showDetails = true } label: {
                        Text("Details")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(OrbPalette.ink)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .glassCapsule()
                    }
                    .buttonStyle(.plain)
                }
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        identity(me)
                        natureSection(soul)
                        coloursSection(me)
                        interestsSection(me, soul)
                        valuesSection(me, soul)
                    }
                    .foregroundStyle(OrbPalette.ink)
                    .padding(.horizontal, 20)
                    .padding(.top, max(0, orbit.profilePanelTop - (orbit.insets.top + 76)))
                    .padding(.bottom, orbit.size.height - orbit.barTop + 24)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(width: orbit.size.width, height: orbit.size.height, alignment: .top)
            .onChange(of: store.me) { _, _ in orbit.refreshMe() }
            .sheet(isPresented: $adding) { AddInterestsSheet(soul: soul) }
            .sheet(isPresented: $orbit.showDetails) { DetailsSheet() }
        }
    }

    // MARK: Sections

    private func identity(_ me: Soul) -> some View {
        VStack(spacing: 6) {
            Text(me.name).font(.system(size: 26, weight: .bold)).tracking(-0.4)
            let line = me.basics?.line ?? ""
            Button { orbit.showDetails = true } label: {
                Text(line.isEmpty ? "Add your age, location and photo" : line)
                    .font(.system(size: 14))
                    .foregroundStyle(line.isEmpty ? Element.tide.color : OrbPalette.muted)
            }
            .buttonStyle(.plain)
            HStack(spacing: 24) {
                stat(orbit.friends.count, "friends")
                stat(me.interests.count, "interests")
                stat(Int(me.remaining.rounded()), "light left")
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    private func natureSection(_ soul: Binding<Soul>) -> some View {
        section("Your nature", "Where you sit on each spectrum sets which colours you are.") {
            VStack(spacing: 18) {
                ForEach(Catalog.traits) { p in
                    NatureSlider(polarity: p, value: soul.wrappedValue.trait(p.id)) { soul.wrappedValue.traits[p.id] = $0 }
                }
            }
        }
    }

    private func coloursSection(_ me: Soul) -> some View {
        let els = me.aura
        let maxW = els.first?.1 ?? 1
        return section("Your colours", "Nature picks the colours. Your interests decide how strongly each one takes hold.") {
            VStack(spacing: 10) {
                ForEach(Array(els.enumerated()), id: \.offset) { _, item in
                    let e = item.0, w = item.1
                    HStack(spacing: 12) {
                        Text(e.name).font(.system(size: 14, weight: .medium)).frame(width: 64, alignment: .leading)
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(OrbPalette.ink.opacity(0.07))
                                Capsule().fill(e.color).frame(width: g.size.width * CGFloat(w / maxW))
                            }
                        }
                        .frame(height: 6)
                        Text("\(Int((w * 100).rounded()))%").font(.system(size: 13)).monospacedDigit()
                            .foregroundStyle(OrbPalette.muted).frame(width: 36, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func interestsSection(_ me: Soul, _ soul: Binding<Soul>) -> some View {
        let ids = me.interests.keys.sorted { (me.interests[$0] ?? 0) > (me.interests[$1] ?? 0) }
        return section("Interests", "Drag a bar to say how much you love it. Tap to pick the specifics.") {
            VStack(spacing: 10) {
                ForEach(ids, id: \.self) { id in
                    if let f = Catalog.facet(id) {
                        InterestCard(facet: f, soul: soul, open: open == id) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { open = open == id ? nil : id }
                        }
                    }
                }
                Button { adding = true } label: {
                    Label("Add interests", systemImage: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Color.white.opacity(0.55), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func valuesSection(_ me: Soul, _ soul: Binding<Soul>) -> some View {
        section("Values", "What you hold. The faint part is what your interests already feed it.") {
            VStack(spacing: 12) {
                ForEach(Catalog.values) { f in
                    ValueBar(facet: f, direct: me.valueWeight(f.id), under: me.undercurrent(into: f.id),
                             limit: me.valueLimit(f.id)) { soul.wrappedValue.setValue(f.id, $0) }
                }
            }
        }
    }

    private func stat(_ n: Int, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text("\(n)").font(.system(size: 18, weight: .semibold)).monospacedDigit()
            Text(label).font(.system(size: 13)).foregroundStyle(OrbPalette.muted)
        }
    }

    private func section<C: View>(_ title: String, _ note: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 20, weight: .bold)).tracking(-0.3)
                Text(note).font(.system(size: 14)).foregroundStyle(OrbPalette.muted).fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
    }
}

// MARK: - A spectrum: Introvert ↔ Extrovert and the rest

struct NatureSlider: View {
    let polarity: Polarity
    let value: Double
    let onChange: (Double) -> Void

    var body: some View {
        let lc = polarity.leftEnergy.color, rc = polarity.rightEnergy.color
        VStack(spacing: 8) {
            HStack {
                Text(polarity.left).font(.system(size: 15, weight: value < -0.12 ? .semibold : .regular))
                    .foregroundStyle(value < -0.12 ? OrbPalette.ink : OrbPalette.muted)
                Spacer()
                Text(reading).font(.system(size: 12, weight: .medium)).foregroundStyle(OrbPalette.muted)
                Spacer()
                Text(polarity.right).font(.system(size: 15, weight: value > 0.12 ? .semibold : .regular))
                    .foregroundStyle(value > 0.12 ? OrbPalette.ink : OrbPalette.muted)
            }
            GeometryReader { g in
                let w = g.size.width, knob: CGFloat = 24
                let x = (w - knob) * CGFloat((value + 1) / 2)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(colors: [lc, lc.opacity(0.25), rc.opacity(0.25), rc], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 6)
                        .padding(.horizontal, knob / 2)
                    HStack(spacing: 0) {
                        ForEach(0..<9, id: \.self) { i in
                            Circle().fill(OrbPalette.ink.opacity(i == 4 ? 0.35 : 0.15)).frame(width: 3, height: 3)
                            if i < 8 { Spacer(minLength: 0) }
                        }
                    }
                    .padding(.horizontal, knob / 2 - 1.5)
                    .offset(y: 11)
                    Circle()
                        .fill(OrbPalette.ink)
                        .overlay(Circle().strokeBorder(value < 0 ? lc : rc, lineWidth: abs(value) > 0.05 ? 2 : 0).padding(-1))
                        .frame(width: knob, height: knob)
                        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                        .offset(x: x)
                }
                .frame(height: knob)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    let raw = Double((v.location.x - knob / 2) / max(1, w - knob)) * 2 - 1
                    let nv = (min(max(raw, -1), 1) * 8).rounded() / 8
                    if nv != value { Resonator.shared.tick(); onChange(nv) }
                })
            }
            .frame(height: 30)
        }
        .accessibilityElement()
        .accessibilityLabel("\(polarity.left) to \(polarity.right)")
        .accessibilityValue(reading)
        .accessibilityAdjustableAction { dir in
            let step = dir == .increment ? 0.125 : -0.125
            onChange(min(1, max(-1, value + step)))
        }
    }

    private var reading: String {
        let a = abs(value)
        if a < 0.13 { return "Balanced" }
        let pole = value < 0 ? polarity.left : polarity.right
        return a > 0.8 ? "Fully \(pole.lowercased())" : a > 0.4 ? "Mostly \(pole.lowercased())" : "Leaning \(pole.lowercased())"
    }
}

// MARK: - One interest: how much, watch or play, and the specifics

struct InterestCard: View {
    let facet: Facet
    @Binding var soul: Soul
    let open: Bool
    let onTap: () -> Void

    var body: some View {
        let id = facet.id
        let w = soul.interestWeight(id)
        let ascended = soul.ascended.contains(id)
        let eng = soul.engagement(id)
        let options = Catalog.specifics[id] ?? []
        let picked = soul.specifics(id)

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle().fill(facet.element.color).frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(facet.name).font(.system(size: 16, weight: .semibold))
                    Text(subtitle(picked: picked, eng: eng, ascended: ascended))
                        .font(.system(size: 13)).foregroundStyle(OrbPalette.muted).lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(OrbPalette.muted)
                    .rotationEffect(.degrees(open ? 180 : 0))
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            LightBar(value: w, ceiling: Soul.interestCeiling, limit: soul.interestLimit(id), color: facet.element.color, locked: ascended) {
                soul.setInterest(id, $0)
            }

            if open {
                if Catalog.engagement[id] != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            ForEach(Engagement.allCases, id: \.self) { m in
                                let on = eng.mode == m
                                Button { soul.setEngagement(id, on && !eng.assumed ? nil : m) } label: {
                                    Text(Catalog.engagementWord(id, m) ?? m.rawValue.capitalized)
                                        .font(.system(size: 13.5, weight: .semibold))
                                        .foregroundStyle(on ? OrbPalette.paper : OrbPalette.ink)
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .background(on ? OrbPalette.ink.opacity(eng.assumed ? 0.45 : 1) : Color.white.opacity(0.6), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if eng.assumed {
                            Text("Assumed from where you sit on Observe to Partake. Tap one to say for sure.")
                                .font(.system(size: 12.5)).foregroundStyle(OrbPalette.muted).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if !options.isEmpty {
                    FlowLayout {
                        ForEach(options, id: \.self) { n in
                            let on = picked.contains(n)
                            Button { soul.toggleSpecific(id, n) } label: {
                                Text(n).font(.system(size: 13.5, weight: .medium))
                                    .foregroundStyle(on ? OrbPalette.paper : OrbPalette.ink)
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(on ? facet.element.color : Color.white.opacity(0.6), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                HStack {
                    if ascended {
                        Button("Bring back to an interest") { soul.descend(id) }
                    } else if soul.canAscend(id), let root = facet.root.flatMap(Catalog.facet) {
                        Button("Ascend into \(root.name)") { Resonator.shared.play(.ascend); soul.ascend(id) }
                    }
                    Spacer()
                    Button("Remove", role: .destructive) { soul.toggleInterest(id) }
                }
                .font(.system(size: 14, weight: .semibold))
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func subtitle(picked: [String], eng: (mode: Engagement, assumed: Bool), ascended: Bool) -> String {
        if ascended, let root = facet.root.flatMap(Catalog.facet) { return "Ascended into \(root.name)" }
        var parts: [String] = []
        if let word = Catalog.engagementWord(facet.id, eng.mode) { parts.append(word + (eng.assumed ? " (assumed)" : "")) }
        if !picked.isEmpty { parts.append(picked.joined(separator: ", ")) }
        return parts.isEmpty ? "Tap to pick specifics" : parts.joined(separator: " · ")
    }
}

/// Drag to spend light. The faint end of the track is what the bank still allows.
struct LightBar: View {
    let value: Double
    let ceiling: Double
    let limit: Double
    let color: Color
    var locked = false
    var under: Double = 0
    let onChange: (Double) -> Void

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(OrbPalette.ink.opacity(0.06))
                Capsule().fill(color.opacity(0.14)).frame(width: w * CGFloat(min(1, limit / ceiling)))
                if under > 0 {
                    Capsule().fill(color.opacity(0.35)).frame(width: w * CGFloat(min(1, (value + under) / ceiling)))
                }
                Capsule().fill(color).frame(width: max(8, w * CGFloat(min(1, value / ceiling))))
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                guard !locked else { return }
                let nv = (Double(v.location.x / max(1, w)) * ceiling).rounded()
                let clamped = min(max(0, nv), limit)
                if clamped != value { Resonator.shared.tick(); onChange(clamped) }
            })
        }
        .frame(height: 10)
        .opacity(locked ? 0.6 : 1)
    }
}

struct ValueBar: View {
    let facet: Facet
    let direct: Double
    let under: Double
    let limit: Double
    let onChange: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle().fill(facet.element.color).frame(width: 8, height: 8)
                Text(facet.name).font(.system(size: 15, weight: .medium))
                Text(facet.line).font(.system(size: 13)).foregroundStyle(OrbPalette.muted).lineLimit(1)
                Spacer()
            }
            LightBar(value: direct, ceiling: Soul.valueCeiling, limit: limit, color: facet.element.color, under: under, onChange: onChange)
        }
    }
}

// MARK: - Add interests

struct AddInterestsSheet: View {
    @Binding var soul: Soul
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Catalog.values) { v in
                    let items = Catalog.interests(rootedIn: v.id)
                    if !items.isEmpty {
                        Section(v.name) {
                            ForEach(items) { f in
                                Button { soul.toggleInterest(f.id) } label: {
                                    HStack {
                                        Circle().fill(f.element.color).frame(width: 8, height: 8)
                                        Text(f.name).foregroundStyle(OrbPalette.ink)
                                        Spacer()
                                        if soul.interests[f.id] != nil {
                                            Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold)).foregroundStyle(OrbPalette.ink)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Interests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("\(Int(soul.remaining.rounded())) light left").font(.system(size: 13)).foregroundStyle(OrbPalette.muted)
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .tint(OrbPalette.ink)
    }
}

// MARK: - Your photo, shown inside your orb on Profile

struct ProfilePhoto: View {
    let orbit: Orbit
    @Environment(Store.self) private var store

    var body: some View {
        let _ = orbit.frame
        ZStack(alignment: .topLeading) {
            if orbit.tab == .profile, let img = store.photo, let you = orbit.engine.orbs.first(where: { $0.anchor }) {
                let p = orbit.toScreen(you.x, you.y)
                let d = CGFloat(you.r * orbit.U * orbit.zoom) * 2 * 0.9
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: d, height: d)
                    .clipShape(Circle())
                    .position(p)
                    .transition(.opacity)
            }
        }
        .frame(width: orbit.size.width, height: orbit.size.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}
