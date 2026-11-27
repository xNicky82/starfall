import SwiftUI

@main
struct StarfallApp: App {
    @State private var store = Store()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
                .tint(SF.blue)
                .background(Color.black)
        }
    }
}

struct RootView: View {
    @Environment(Store.self) private var store
    @State private var tab = UserDefaults.standard.integer(forKey: "tab") // launch arg `-tab N`

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if store.me == nil {
                AttuneFlow().transition(.opacity)
            } else {
                ZStack(alignment: .bottom) {
                    Group {
                        switch tab {
                        case 1: EssenceView()
                        case 2: ConstellationView()
                        default: DriftView()
                        }
                    }
                    .transition(.opacity)
                    if !store.inEncounter {
                        OrbitBar(selection: $tab, me: store.me)
                            .transition(.opacity)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.8), value: store.me == nil)
    }
}

/// Three circles. No words.
struct OrbitBar: View {
    @Binding var selection: Int
    var me: Soul?

    var body: some View {
        HStack(spacing: 56) {
            item(0) { Circle().stroke(SF.paper, lineWidth: 1).frame(width: 14, height: 14) }
            item(1) { PlanetGlyph(colors: me?.auraColors ?? [SF.blue], radius: 6, spread: 0.8) }
            item(2) {
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle().fill(SF.paper).frame(width: 3, height: 3)
                            .offset(x: CGFloat([-7, 6, 1][i]), y: CGFloat([4, 5, -7][i]))
                    }
                }
            }
        }
        .padding(.top, 18)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea())
    }

    private func item<C: View>(_ i: Int, @ViewBuilder _ icon: () -> C) -> some View {
        let on = selection == i
        return icon()
            .frame(width: 44, height: 44)
            .opacity(on ? 1 : 0.38)
            .contentShape(Circle())
            .onTapGesture {
                guard !on else { return }
                Resonator.shared.play(.snap)
                withAnimation(.easeInOut(duration: 0.45)) { selection = i }
            }
    }
}
