import SwiftUI

struct AttuneFlow: View {
    @Environment(Store.self) private var store
    @State private var soul = Soul(name: "")
    @State private var step = 0
    @FocusState private var nameFocused: Bool

    private var named: Bool { !soul.name.trimmingCharacters(in: .whitespaces).isEmpty }
    private var canContinue: Bool {
        switch step {
        case 0: return named
        case 1: return soul.interests.count >= 2
        default: return true
        }
    }

    var body: some View {
        ZStack {
            Paper().onTapGesture { nameFocused = false }
            VStack(spacing: 0) {
                header
                Group {
                    switch step {
                    case 0: arrival
                    case 5: reveal
                    default: realm
                    }
                }
                .id(step)
                .transition(.opacity)
                .frame(maxHeight: .infinity)
                SlotSlider(enabled: canContinue) { advance() }
                    .padding(.horizontal, 36)
                    .padding(.bottom, 18)
            }
        }
    }

    private func advance() {
        nameFocused = false
        if step == 5 { store.me = soul; return }
        withAnimation(.easeInOut(duration: 0.45)) { step += 1 }
    }

    private var header: some View {
        HStack {
            Circle().stroke(SF.hair, lineWidth: SF.line).frame(width: 28, height: 28)
                .overlay(Image(systemName: "chevron.left").font(.system(size: 9, weight: .light)).foregroundStyle(SF.mist))
                .contentShape(Circle())
                .onTapGesture { withAnimation(.easeInOut(duration: 0.45)) { step = max(0, step - 1) } }
                .opacity(step > 0 ? 1 : 0)
            Spacer()
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { i in
                    Circle().fill(i == step ? SF.blue : SF.hair).frame(width: 4, height: 4)
                }
            }
            Spacer()
            Group { if step == 2 || step == 4 { LightGauge(remaining: soul.remaining) } else { Color.clear } }
                .frame(width: 30, height: 30)
        }
        .padding(.horizontal, 22)
        .padding(.top, 6)
    }

    private var arrival: some View {
        VStack(spacing: 0) {
            Spacer()
            AttractorView(params: .classic, steps: 6000, drawIn: 7, spin: 0.04)
                .frame(width: 300, height: 330)
            Spacer()
            TextField("", text: $soul.name, prompt: Text("name").foregroundStyle(SF.mist))
                .font(SF.mono(15)).multilineTextAlignment(.center).foregroundStyle(SF.ink)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($nameFocused).submitLabel(.done)
                .frame(width: 220)
            Rectangle().fill(SF.hair).frame(width: 160, height: SF.line).padding(.top, 6)
            Spacer().frame(height: 40)
        }
    }

    private var realm: some View {
        ScrollView(showsIndicators: false) {
            Group {
                switch step {
                case 1: InterestPicker(soul: $soul)
                case 2: InterestWeigher(soul: $soul)
                case 3: TraitsEditor(soul: $soul)
                default: ValuesEditor(soul: $soul)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 26)
        }
    }

    private var reveal: some View {
        VStack(spacing: 18) {
            Spacer()
            AttractorView(params: soul.lorenz, steps: 6000, drawIn: 5, spin: 0.05)
                .frame(width: 300, height: 330)
            Text(soul.name.lowercased()).label(13)
            Spacer()
        }
    }
}
