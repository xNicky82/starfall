import SwiftUI

/// The awakening: name → gather interests → weigh → traits → values → reveal.
struct AttuneFlow: View {
    @Environment(Store.self) private var store
    @State private var soul = Soul(name: "")
    @State private var step = 0
    @FocusState private var nameFocused: Bool

    private let steps = 6

    var body: some View {
        ZStack {
            SanctuaryBackground(glow: step == 0 ? SF.blue : soul.hue)
            VStack(spacing: 0) {
                header
                Group {
                    switch step {
                    case 0: arrival
                    case 1: page("Gather", "What do you love to do?",
                                 "Touch the circles that pull at you. Nothing is weighed yet.") { InterestPicker(soul: $soul) }
                    case 2: page("Weigh", "You only have so much light.",
                                 "Loving one thing costs loving another. Push an interest all the way into its slot and it stops being a hobby — it ascends into a value.") {
                                     InterestWeigher(soul: $soul) }
                    case 3: page("Temper", "How do you move through the world?",
                                 "Slide toward the pole you live closer to. There is no good side.") { TraitsEditor(soul: $soul) }
                    case 4: page("Hold", "What do you hold sacred?",
                                 "Your interests already flow into your values. Spend what light remains.") { ValuesEditor(soul: $soul) }
                    default: reveal
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
                .id(step)
                footer
            }
        }
    }

    // MARK: Chrome

    private var header: some View {
        HStack(spacing: 14) {
            Circle().stroke(SF.faint).frame(width: 36, height: 36)
                .overlay(Image(systemName: "chevron.left").font(.system(size: 13, weight: .medium)).foregroundStyle(SF.mist))
                .contentShape(Circle())
                .onTapGesture { withAnimation(.spring(response: 0.5)) { step = max(0, step - 1) } }
                .opacity(step > 0 ? 1 : 0)
            Spacer()
            HStack(spacing: 7) {
                ForEach(0..<steps, id: \.self) { i in
                    Circle().fill(i <= step ? (step == 0 ? SF.blue : soul.hue) : SF.faint)
                        .frame(width: i == step ? 9 : 6, height: i == step ? 9 : 6)
                }
            }
            Spacer()
            if step == 2 || step == 4 { LightRing(spent: soul.spent, size: 44) } else { Color.clear.frame(width: 44, height: 44) }
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .frame(height: 56)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            if let hint { Text(hint).font(SF.body(12)).foregroundStyle(SF.mist) }
            SlotSlider(label: step == 0 ? "slide to begin" : step == steps - 1 ? "slide to fall" : "slide to continue",
                       tint: step == 0 ? SF.blue : soul.hue,
                       colors: step == steps - 1 ? soul.auraColors : nil) { advance() }
                .disabled(hint != nil)
                .opacity(hint == nil ? 1 : 0.4)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 12)
        .padding(.top, 10)
    }

    private var hint: String? {
        switch step {
        case 0: return soul.name.trimmingCharacters(in: .whitespaces).isEmpty ? "Tell us what to call you." : nil
        case 1: return soul.interests.count < 2 ? "Gather at least two." : nil
        default: return nil
        }
    }

    private func advance() {
        nameFocused = false
        if step == steps - 1 {
            store.me = soul
            return
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) { step += 1 }
    }

    private func page<C: View>(_ eyebrow: String, _ title: String, _ sub: String, @ViewBuilder _ content: () -> C) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                Text(eyebrow).eyebrow(soul.hue)
                Text(title).title(30).fixedSize(horizontal: false, vertical: true)
                Text(sub).font(SF.body(14)).foregroundStyle(SF.mist).fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 18)
                content()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
    }

    // MARK: Steps

    private var arrival: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                OrbitGuides(count: 3).frame(width: 330, height: 330)
                OrbView(colors: [SF.blue, Element.aether.color, .white]).frame(width: 300, height: 300)
            }
            Text("STARFALL").font(SF.display(30)).tracking(12).foregroundStyle(SF.ink).padding(.top, 4)
            Text("Every soul drifts. Some collide.").font(SF.body(14)).foregroundStyle(SF.mist).padding(.top, 8)
            Spacer()
            VStack(spacing: 8) {
                TextField("", text: $soul.name, prompt: Text("your name").foregroundStyle(SF.ink.opacity(0.3)))
                    .font(SF.display(24)).multilineTextAlignment(.center).foregroundStyle(SF.ink)
                    .textInputAutocapitalization(.words).autocorrectionDisabled()
                    .focused($nameFocused).submitLabel(.done)
                Rectangle().fill(SF.faint).frame(width: 180, height: 1)
            }
            .padding(.bottom, 24)
        }
        .contentShape(Rectangle())
        .onTapGesture { nameFocused = false }
    }

    private var reveal: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                Text("Your light").eyebrow(soul.hue).padding(.top, 6)
                OrbView(colors: soul.auraColors).frame(width: 320, height: 320).padding(.vertical, -30)
                Text(soul.name).title(34)
                ElementBar(soul: soul).padding(.horizontal, 6)
                VStack(alignment: .leading, spacing: 12) {
                    Text("You hold").eyebrow()
                    FlowRow(items: soul.topValues.prefix(5).map { ($0.0, $0.1) })
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("Once you fall, you'll drift among other souls. When your light touches theirs, you'll feel it.")
                    .font(SF.body(14)).foregroundStyle(SF.mist).multilineTextAlignment(.center).padding(.top, 4)
            }
            .padding(.horizontal, 24)
        }
    }
}

/// Values as soft pills sized by weight.
struct FlowRow: View {
    var items: [(Facet, Double)]
    var body: some View {
        let maxW = items.map(\.1).max() ?? 1
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.0.id) { f, w in
                HStack(spacing: 10) {
                    Glyph(element: f.element, size: 10)
                    Text(f.name).font(SF.display(15)).foregroundStyle(SF.ink).frame(width: 90, alignment: .leading)
                    GeometryReader { g in
                        Capsule().fill(f.element.color.opacity(0.85)).frame(width: g.size.width * w / maxW, height: 6)
                            .frame(maxHeight: .infinity)
                    }
                    .frame(height: 14)
                }
            }
        }
    }
}
