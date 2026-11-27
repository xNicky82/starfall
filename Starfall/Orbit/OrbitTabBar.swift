import SwiftUI

/// Floating glass capsule. A single orb (drawn by the `tabOrb` shader) lives inside it: it slides to the
/// chosen tab, smearing your energy colours behind it, then settles into that tab's icon shape.
struct OrbitTabBar: View {
    let orbit: Orbit

    /// Vertical centre of the icon row inside the 62pt bar.
    static let iconY: Float = 23

    var body: some View {
        let _ = orbit.frame
        let u = orbit.tabUniforms()
        ZStack {
            Rectangle()
                .fill(Color.white)
                .colorEffect(ShaderLibrary.tabOrb(
                    .float2(Float(orbit.tabX), OrbitTabBar.iconY),
                    .float(Float(orbit.tabMorph)),
                    .float(Float(orbit.tab.rawValue)),
                    .float(Float(orbit.tabStretch)),
                    .floatArray(u.offs),
                    .floatArray(u.depth),
                    .floatArray(OrbPalette.flat)))
                .allowsHitTesting(false)

            HStack(spacing: 0) {
                ForEach(OrbitTab.allCases) { t in
                    let on = t == orbit.tab
                    Button { orbit.select(t) } label: {
                        VStack(spacing: 3) {
                            Image(systemName: t.symbol)
                                .font(.system(size: 21, weight: .regular))
                                .frame(height: 28)
                                .opacity(on ? 0 : 1) // the orb becomes this icon
                            Text(t.title).font(.system(size: 10.5, weight: on ? .semibold : .medium))
                        }
                        .foregroundStyle(on ? OrbPalette.ink : OrbPalette.ink.opacity(0.62))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .overlay(alignment: .top) {
                            if t == .inbox && orbit.hasUnread {
                                Circle().fill(OrbPalette.color(.ember)).frame(width: 8, height: 8)
                                    .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 2))
                                    .offset(x: 12, y: 8)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(t.title)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(4)
        }
        .frame(height: 62)
        .background {
            GeometryReader { g in
                Color.clear
                    .onAppear { orbit.barWidth = g.size.width }
                    .onChange(of: g.size.width) { _, w in orbit.barWidth = w }
            }
        }
        .clipShape(Capsule())
        .glassCapsule()
    }
}

extension OrbPalette {
    static func color(_ e: Element) -> Color { e.color }
}
