import SwiftUI

@main
struct StarfallApp: App {
    @State private var store = Store()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.light)
                .tint(SF.blue)
        }
    }
}

struct RootView: View {
    @Environment(Store.self) private var store
    @State private var tab = 0

    var body: some View {
        Group {
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
                    OrbitBar(selection: $tab, me: store.me)
                        .padding(.bottom, 8)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: store.me == nil)
    }
}

/// Navigation as three circles.
struct OrbitBar: View {
    @Binding var selection: Int
    var me: Soul?

    var body: some View {
        HStack(spacing: 34) {
            item(0, "Drift") {
                ZStack {
                    Circle().stroke(SF.ink.opacity(0.5), lineWidth: 1).frame(width: 22, height: 22)
                    Circle().fill(SF.ink.opacity(0.6)).frame(width: 6, height: 6).offset(x: 11)
                }
            }
            item(1, "Essence") {
                OrbView(colors: me?.auraColors ?? [SF.blue]).frame(width: 64, height: 64)
            }
            item(2, "Bonds") {
                ZStack {
                    ForEach(0..<3) { i in
                        Circle().fill(SF.ink.opacity(0.6)).frame(width: 5, height: 5)
                            .offset(x: CGFloat([-8, 7, 2][i]), y: CGFloat([5, 6, -8][i]))
                    }
                }
            }
        }
        .padding(.horizontal, 26).padding(.vertical, 10)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().stroke(Color.white.opacity(0.6), lineWidth: 1))
        .shadow(color: SF.ink.opacity(0.08), radius: 18, y: 6)
    }

    private func item<C: View>(_ i: Int, _ name: String, @ViewBuilder _ icon: () -> C) -> some View {
        let on = selection == i
        return VStack(spacing: 5) {
            ZStack {
                Circle().fill(on ? Color.white : Color.clear).frame(width: 48, height: 48)
                    .shadow(color: on ? SF.blue.opacity(0.3) : .clear, radius: 10)
                icon().frame(width: 28, height: 28)
            }
            .frame(width: 48, height: 48)
            Text(name).font(SF.label(9)).tracking(2).textCase(.uppercase).foregroundStyle(on ? SF.ink : SF.mist)
        }
        .contentShape(Circle())
        .onTapGesture {
            guard !on else { return }
            Resonator.shared.play(.snap)
            withAnimation(.easeInOut(duration: 0.35)) { selection = i }
        }
    }
}
