import SwiftUI

struct AttuneFlow: View {
    @Environment(Store.self) private var store
    @State private var soul = Soul(name: "")
    @State private var step = 0
    @FocusState private var nameFocused: Bool

    private var named: Bool { !soul.name.trimmingCharacters(in: .whitespaces).isEmpty }
    private var auraOrBlue: [Color] { soul.isAttuned ? soul.auraColors : [SF.blue] }

    var body: some View {
        ZStack {
            Sky()
            Group {
                switch step {
                case 0: arrival
                case 5: reveal
                default: realm
                }
            }
            .id(step)
            .transition(.opacity)
        }
    }

    private func go(_ s: Int) {
        nameFocused = false
        withAnimation(.easeInOut(duration: 0.7)) { step = max(0, s) }
    }

    // MARK: Arrival

    private var arrival: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                DescentGate(ready: named, colors: [SF.blue], horizon: 0.56, radius: 0.56, gap: 0.2, trail: 0.26,
                            spread: 1.5, alwaysVisible: true) { go(1) }
                TextField("", text: $soul.name, prompt: Text("name").foregroundStyle(SF.paper.opacity(0.2)))
                    .font(SF.type(17)).tracking(5).multilineTextAlignment(.center)
                    .foregroundStyle(SF.paper)
                    .textInputAutocapitalization(.words).autocorrectionDisabled()
                    .focused($nameFocused).submitLabel(.done)
                    .frame(width: w * 0.7)
                    .position(x: w / 2, y: h * 0.56 - w * 0.46 - 110)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: Reveal

    private var reveal: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                DescentGate(ready: true, colors: soul.auraColors, horizon: 0.56, radius: 0.56, gap: 0.2, trail: 0.26,
                            spread: 1.5, alwaysVisible: true, headColor: soul.hue) { store.me = soul }
                Text(soul.name).caption(15, SF.paper)
                    .position(x: w / 2, y: h * 0.56 + w * 0.2)
                    .allowsHitTesting(false)
                back.position(x: 36, y: 74)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: Gather · Weigh · Temper · Hold

    private var realm: some View {
        VStack(spacing: 0) {
            HStack {
                back
                Spacer()
                HStack(spacing: 9) {
                    ForEach(0..<6, id: \.self) { i in
                        Circle().fill(i == step ? SF.paper : SF.faint).frame(width: 4, height: 4)
                    }
                }
                Spacer()
                Group {
                    if step == 2 || step == 4 { LightGauge(remaining: soul.remaining) } else { Color.clear }
                }
                .frame(width: 30, height: 30)
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)

            ScrollView(showsIndicators: false) {
                Group {
                    switch step {
                    case 1: InterestField(soul: $soul)
                    case 2: InterestWeigher(soul: $soul)
                    case 3: TraitsEditor(soul: $soul)
                    default: ValuesEditor(soul: $soul)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 22)
            }
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.04),
                                         .init(color: .black, location: 0.93), .init(color: .clear, location: 1)],
                                 startPoint: .top, endPoint: .bottom))

            DescentGate(ready: step != 1 || soul.interests.count >= 2, colors: auraOrBlue,
                        horizon: 0.6, radius: 1.4, gap: 0.2, trail: 0.13, spread: 0.45) { go(step + 1) }
                .frame(height: 200)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var back: some View {
        Circle().stroke(SF.faint, lineWidth: 1).frame(width: 30, height: 30)
            .overlay(Image(systemName: "chevron.left").font(.system(size: 10, weight: .light)).foregroundStyle(SF.mist))
            .contentShape(Circle())
            .onTapGesture { go(step - 1) }
    }
}
