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

    var body: some View {
        ZStack {
            Paper()
            if store.me == nil {
                AttuneFlow().transition(.opacity)
            } else {
                // One persistent orb field; tabs move orbs instead of swapping screens.
                OrbitRoot().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: store.me == nil)
    }
}
