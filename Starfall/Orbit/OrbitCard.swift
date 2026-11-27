import SwiftUI

/// Dark card that rises above the tab bar. The field re-centres above it so nothing hides.
struct OrbitCardHost: View {
    let orbit: Orbit

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            if let s = orbit.sheet {
                Group {
                    switch s {
                    case .person(let id): PersonCard(orbit: orbit, id: id)
                    case .read: ReadCard(orbit: orbit)
                    }
                }
                .padding(20)
                .frame(maxWidth: 460, alignment: .leading)
                .background(OrbPalette.ink, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .black.opacity(0.22), radius: 25, y: 18)
                .foregroundStyle(OrbPalette.paper)
                .padding(.horizontal, max(10, orbit.insets.leading))
                .background(GeometryReader { g in
                    Color.clear
                        .onAppear { orbit.cardHeight = g.size.height; orbit.refreshRegion() }
                        .onChange(of: g.size.height) { _, h in orbit.cardHeight = h; orbit.refreshRegion() }
                })
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, orbit.size.height - orbit.barTop + 10)
        .frame(width: orbit.size.width, height: orbit.size.height)
    }
}

struct PersonCard: View {
    let orbit: Orbit
    let id: UUID

    var body: some View {
        if let s = orbit.soul(id) {
            let me = orbit.me
            let r = orbit.resonance(me, s)
            let nearby = orbit.tab == .home
            let mine = Set(me.interests.keys)
            let only = s.activeInterests.map { $0.0 }.filter { !mine.contains($0.id) }
            let shared = r.sharedInterests.compactMap { Catalog.facet($0) }
            let values = r.sharedValues.prefix(3).compactMap { Catalog.facet($0) }
            let here = orbit.engine.orbs.filter { $0.alive && !$0.anchor && $0.id != id }
                .map { ($0.soul, orbit.resonance(s, $0.soul).score) }.sorted { $0.1 > $1.1 }.prefix(4)
            let neverMet: Soul? = nearby ? nil : orbit.friends.filter { $0.id != id }
                .max { orbit.resonance(s, $0).score < orbit.resonance(s, $1).score }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(nearby ? "Nearby · \(orbit.distance(s))" : "Friend · resonance with you")
                                .font(.system(size: 13, weight: .medium)).opacity(0.6)
                            Text(s.name).font(.system(size: 24, weight: .bold)).tracking(-0.4)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(alignment: .top, spacing: 1) {
                                Text("\(orbit.pct(s))").font(.system(size: 42, weight: .semibold)).tracking(-1.4)
                                Text("%").font(.system(size: 17, weight: .semibold)).padding(.top, 3)
                            }
                            .monospacedDigit()
                            Text(r.meeting.rawValue.capitalized).font(.system(size: 12, weight: .semibold)).opacity(0.6)
                        }
                    }
                    EnergyBar(weights: shareWeights(me, s))

                    group("\(s.name)'s colours") {
                        EnergyBar(weights: s.elements, thin: true)
                        HStack(spacing: 14) {
                            ForEach(Array(s.aura.prefix(3).enumerated()), id: \.offset) { _, item in
                                Text("\(item.0.name) ").font(.system(size: 14))
                                    + Text("\(Int((item.1 * 100).rounded()))%").font(.system(size: 14)).foregroundColor(OrbPalette.paper.opacity(0.6))
                            }
                        }
                    }
                    group("Shared · \(shared.count + values.count)") {
                        if shared.isEmpty && values.isEmpty {
                            Text("Nothing in common yet, so \(s.name) keeps a gap and the edge stays dark.")
                                .font(.system(size: 14)).opacity(0.6)
                        } else {
                            FlowLayout {
                                ForEach(shared) { OrbChip(text: $0.name, color: $0.element.color) }
                                ForEach(values) { OrbChip(text: $0.name, color: $0.element.color) }
                            }
                        }
                    }
                    if !r.sharedSpecifics.isEmpty {
                        group("Specifically") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(r.sharedSpecifics.prefix(4).enumerated()), id: \.offset) { _, sp in
                                    Text(specificLine(sp.interest, sp.name, me, s)).font(.system(size: 14))
                                }
                            }
                        }
                    }
                    if !only.isEmpty {
                        group("Only \(s.name)") {
                            FlowLayout { ForEach(only) { OrbChip(text: $0.name, color: $0.element.color, dim: true) } }
                        }
                    }
                    if !nearby && !here.isEmpty {
                        group("\(s.name) with the others here") {
                            FlowLayout(spacing: 14) {
                                ForEach(Array(here.enumerated()), id: \.offset) { _, item in
                                    Text("\(item.0.name) ").font(.system(size: 14))
                                        + Text("\(Int((item.1 * 100).rounded()))%").font(.system(size: 14)).foregroundColor(OrbPalette.paper.opacity(0.6))
                                }
                            }
                        }
                    }
                    if let n = neverMet {
                        group("Never met, would click") {
                            Text("\(n.name) ").font(.system(size: 14))
                                + Text("\(Int((orbit.resonance(s, n).score * 100).rounded()))%").font(.system(size: 14)).foregroundColor(OrbPalette.paper.opacity(0.6))
                        }
                    }
                    HStack(spacing: 8) {
                        Spacer()
                        if nearby {
                            ghost("Pass") { orbit.pass(id) }
                            solid("Say hi") { orbit.sayHi(id) }
                        } else {
                            ghost("Close") { orbit.closeSheet() }
                            solid("Message") { orbit.message(id) }
                        }
                    }
                }
            }
            .frame(maxHeight: orbit.size.height * 0.5)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// "Hockey · you watch, Theo plays" — watch or play is assumed from Observe ↔ Partake when not stated.
    private func specificLine(_ interest: String, _ name: String, _ me: Soul, _ s: Soul) -> String {
        guard let w = Catalog.engagement[interest] else { return name }
        func conjugate(_ v: String) -> String {
            var parts = v.split(separator: " ").map(String.init)
            guard var first = parts.first else { return v }
            if first == "go" || first == "do" || ["ch", "sh", "s", "x"].contains(where: { first.hasSuffix($0) }) { first += "es" } else { first += "s" }
            parts[0] = first
            return parts.joined(separator: " ")
        }
        func verb(_ e: Engagement, _ third: Bool) -> String {
            let base: String
            switch e {
            case .watch: base = w.watch.lowercased()
            case .play: base = w.play.lowercased()
            case .both: base = "do both"
            }
            return third ? conjugate(base) : base
        }
        let a = me.engagement(interest).mode, b = s.engagement(interest).mode
        if a == b { return "\(name) · you both \(verb(a, false))" }
        return "\(name) · you \(verb(a, false)), \(s.name) \(verb(b, true))"
    }

    private func shareWeights(_ a: Soul, _ b: Soul) -> [Element: Double] {
        let ea = a.elements, eb = b.elements
        var out: [Element: Double] = [:]
        for e in Element.allCases { out[e] = min(ea[e] ?? 0, eb[e] ?? 0) }
        return out
    }
}

/// Friends: how the whole group fits, and who has never met but would click.
struct ReadCard: View {
    let orbit: Orbit

    var body: some View {
        let me = orbit.me
        let fr = orbit.friends
        let all = [me] + fr
        let pairs = all.indices.flatMap { i in all.indices.filter { $0 > i }.map { (all[i], all[$0]) } }
        let scores = pairs.map { orbit.resonance($0.0, $0.1).score }
        let cohesion = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
        let strangers = pairs.filter { $0.0.id != me.id && $0.1.id != me.id }
            .map { ($0.0, $0.1, orbit.resonance($0.0, $0.1)) }
            .sorted { $0.2.score > $1.2.score }.prefix(3)
        let avg: (Soul) -> Double = { s in
            let xs = all.filter { $0.id != s.id }.map { orbit.resonance(s, $0).score }
            return xs.reduce(0, +) / Double(max(1, xs.count))
        }
        let ranked = fr.map { ($0, avg($0)) }.sorted { $0.1 > $1.1 }

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Circle read · \(fr.count) friends").font(.system(size: 13, weight: .medium)).opacity(0.6)
                        Text("Everyone").font(.system(size: 24, weight: .bold)).tracking(-0.4)
                    }
                    Spacer()
                    HStack(alignment: .top, spacing: 1) {
                        Text("\(Int((cohesion * 100).rounded()))").font(.system(size: 42, weight: .semibold)).tracking(-1.4)
                        Text("%").font(.system(size: 17, weight: .semibold)).padding(.top, 3)
                    }
                    .monospacedDigit()
                }
                Text("Average resonance across every pairing.").font(.system(size: 14)).opacity(0.6)
                if !strangers.isEmpty {
                    group("Never met, would click") {
                        VStack(spacing: 8) {
                            ForEach(Array(strangers.enumerated()), id: \.offset) { _, p in
                                row("\(p.0.name) + \(p.1.name)", p.2.score, line(p.2))
                            }
                        }
                    }
                }
                if let b = ranked.first {
                    group("The bridge") {
                        row(b.0.name, b.1, "Highest average with everyone, so the easiest person to build plans around.")
                    }
                }
                if let d = ranked.last, ranked.count > 2, d.1 < (ranked.first?.1 ?? 0) - 0.08 {
                    group("Drifting") { row(d.0.name, d.1, "Least overlap with the rest of the group.") }
                }
                HStack { Spacer(); ghost("Close") { orbit.closeSheet() } }
            }
        }
        .frame(maxHeight: orbit.size.height * 0.5)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func line(_ r: Resonance) -> String {
        let names = (r.sharedInterests + r.sharedValues).prefix(3).compactMap { Catalog.facet($0)?.name.lowercased() }
        guard !names.isEmpty else { return "They overlap in energy more than in specifics." }
        return "Both into " + names.joined(separator: ", ") + "."
    }
    private func row(_ title: String, _ score: Double, _ note: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(Int((score * 100).rounded()))%").font(.system(size: 15, weight: .semibold)).monospacedDigit()
            }
            Text(note).font(.system(size: 13.5)).opacity(0.6).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(OrbPalette.ink2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Shared pieces

private func group<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title).font(.system(size: 13, weight: .semibold)).opacity(0.6)
        content()
    }
}
private func ghost(_ title: String, _ action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title).font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 15).padding(.vertical, 11)
            .overlay(Capsule().strokeBorder(OrbPalette.paper.opacity(0.22), lineWidth: 1))
    }
    .buttonStyle(.plain)
}
private func solid(_ title: String, _ action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title).font(.system(size: 14, weight: .semibold))
            .foregroundStyle(OrbPalette.ink)
            .padding(.horizontal, 16).padding(.vertical, 11)
            .background(OrbPalette.paper, in: Capsule())
    }
    .buttonStyle(.plain)
}

struct OrbChip: View {
    let text: String
    let color: Color
    var dim = false
    var light = false

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(dim ? Color.clear : color)
                .overlay(Circle().strokeBorder(dim ? OrbPalette.paper.opacity(0.6) : .clear, lineWidth: 1))
                .frame(width: 7, height: 7)
            Text(text).font(.system(size: 13.5, weight: .medium))
        }
        .foregroundStyle(light ? OrbPalette.ink : (dim ? OrbPalette.paper.opacity(0.6) : OrbPalette.paper))
        .padding(.leading, 10).padding(.trailing, 12).padding(.vertical, 8)
        .background(light ? Color.white.opacity(0.6) : OrbPalette.ink2, in: Capsule())
    }
}

/// Proportional strip of energy colours.
struct EnergyBar: View {
    let weights: [Element: Double]
    var thin = false

    var body: some View {
        let items = Element.allCases.map { ($0, weights[$0] ?? 0) }.filter { $0.1 > 0.02 }
        let tot = items.reduce(0) { $0 + $1.1 }
        GeometryReader { g in
            HStack(spacing: 2) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    let e = item.0, w = item.1
                    Rectangle().fill(e.color)
                        .frame(width: max(0, (g.size.width - CGFloat(max(0, items.count - 1)) * 2) * CGFloat(w / max(tot, 1e-6))))
                }
            }
        }
        .frame(height: thin ? 4 : 8)
        .background(OrbPalette.ink2)
        .clipShape(Capsule())
    }
}

/// Wraps chips onto as many lines as they need.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, w: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > maxW { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
            w = max(w, x - spacing)
        }
        return CGSize(width: min(w, maxW), height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + sz.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}
