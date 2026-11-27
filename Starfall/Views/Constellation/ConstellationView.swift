import SwiftUI

/// Everyone you bonded with, as their attractor.
struct ConstellationView: View {
    @Environment(Store.self) private var store
    private let cols = [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)]

    var body: some View {
        let bonded = store.bonded.compactMap { b in store.soul(b.soulID).map { (b, $0) } }
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: cols, spacing: 26) {
                ForEach(bonded, id: \.0.id) { rec, soul in
                    VStack(spacing: 10) {
                        AttractorView(params: soul.lorenz, steps: 3000, color: SF.blue, spin: 0)
                            .frame(height: 170)
                        HStack {
                            Text(soul.name.lowercased()).label(10)
                            Spacer()
                            Text(String(format: "%.2f", rec.score)).label(9, SF.mist).monospacedDigit()
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 30)
            .padding(.bottom, 120)
        }
        .background(Paper())
    }
}
