import SwiftUI

/// Starfall design tokens.
/// Paper (233,233,233) + Starfall Blue (60,135,237); Futura for the Bauhaus voice.
enum SF {
    static let paper = Color(red: 233/255, green: 233/255, blue: 233/255)
    static let blue  = Color(red: 60/255,  green: 135/255, blue: 237/255)
    static let ink   = Color(red: 0.10, green: 0.11, blue: 0.14)
    static let mist  = Color(red: 0.10, green: 0.11, blue: 0.14).opacity(0.48)
    static let faint = Color(red: 0.10, green: 0.11, blue: 0.14).opacity(0.10)
    static let card  = Color.white.opacity(0.55)

    static func display(_ size: CGFloat) -> Font { .custom("Futura-Medium", size: size) }
    static func heavy(_ size: CGFloat) -> Font { .custom("Futura-Bold", size: size) }
    static func label(_ size: CGFloat = 11) -> Font { .custom("Futura-Medium", size: size) }
    static func body(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .regular) }
}

extension View {
    /// Small, wide-tracked uppercase caption — the sanctuary signage voice.
    func eyebrow(_ color: Color = SF.mist) -> some View {
        self.font(SF.label(11)).tracking(3.2).textCase(.uppercase).foregroundStyle(color)
    }
    func title(_ size: CGFloat = 34) -> some View {
        self.font(SF.display(size)).tracking(1).foregroundStyle(SF.ink)
    }
}

/// Soft paper background with a slow breathing wash of blue light.
struct SanctuaryBackground: View {
    var glow: Color = SF.blue
    var body: some View {
        TimelineView(.animation(minimumInterval: 1/20)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let breath = 0.5 + 0.5 * sin(t * 2 * .pi / 9) // ~9s breath
            ZStack {
                SF.paper
                RadialGradient(colors: [glow.opacity(0.10 + 0.06 * breath), .clear],
                               center: UnitPoint(x: 0.5, y: 0.08), startRadius: 0, endRadius: 520)
                RadialGradient(colors: [Color.white.opacity(0.7), .clear],
                               center: UnitPoint(x: 0.5, y: 1.05), startRadius: 0, endRadius: 420)
            }
        }
        .ignoresSafeArea()
    }
}

/// Bauhaus primitive: concentric guide circles, very faint.
struct OrbitGuides: View {
    var count = 4
    var body: some View {
        GeometryReader { geo in
            let m = min(geo.size.width, geo.size.height)
            ZStack {
                ForEach(1...count, id: \.self) { i in
                    Circle()
                        .stroke(SF.faint, lineWidth: 0.6)
                        .frame(width: m * CGFloat(i) / CGFloat(count), height: m * CGFloat(i) / CGFloat(count))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
    }
}
