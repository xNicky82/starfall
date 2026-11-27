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
    @State private var tab = UserDefaults.standard.integer(forKey: "tab") // launch arg `-tab N`

    var body: some View {
        ZStack {
            Paper()
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
                        OrbitBar(selection: $tab).transition(.opacity)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: store.me == nil)
    }
}

/// Three circles. Field · you · bonds.
struct OrbitBar: View {
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 64) {
            item(0) { on in
                ZStack {
                    Circle().stroke(on ? SF.blue : SF.mist, lineWidth: SF.line).frame(width: 18, height: 18)
                    Circle().fill(on ? SF.blue : SF.mist).frame(width: 4, height: 4).offset(x: 9)
                }
            }
            item(1) { on in
                ZStack {
                    Circle().stroke(on ? SF.blue : SF.mist, lineWidth: SF.line).frame(width: 18, height: 18)
                    Circle().fill(on ? SF.blue : SF.mist).frame(width: 6, height: 6)
                }
            }
            item(2) { on in
                ZStack {
                    Circle().stroke(on ? SF.blue : SF.mist, lineWidth: SF.line).frame(width: 15, height: 15).offset(x: -4)
                    Circle().stroke(on ? SF.blue : SF.mist, lineWidth: SF.line).frame(width: 15, height: 15).offset(x: 4)
                }
            }
        }
        .padding(.top, 14)
        .frame(maxWidth: .infinity)
        .background(LinearGradient(colors: [SF.paper.opacity(0), SF.paper], startPoint: .top, endPoint: .center)
            .ignoresSafeArea())
    }

    private func item<C: View>(_ i: Int, @ViewBuilder _ icon: (Bool) -> C) -> some View {
        let on = selection == i
        return icon(on)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .onTapGesture {
                guard !on else { return }
                Resonator.shared.play(.snap)
                withAnimation(.easeInOut(duration: 0.35)) { selection = i }
            }
    }
}
