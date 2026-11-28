import SwiftUI

@main
struct StarfallApp: App {
    @State private var store = Store()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.light)
                .tint(OrbPalette.ink)
        }
    }
}

struct RootView: View {
    @Environment(Store.self) private var store

    var body: some View {
        // One persistent orb field. Onboarding, tabs and everything else happen inside it.
        OrbitRoot()
            .id(store.epoch)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.6), value: store.epoch)
    }
}
