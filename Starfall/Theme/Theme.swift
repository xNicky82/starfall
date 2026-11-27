import SwiftUI

/// Paper, one blue ink, hairlines, monospace. Nothing else.
enum SF {
    static let paper = Color(red: 233/255, green: 233/255, blue: 233/255)
    static let blue  = Color(red: 60/255,  green: 135/255, blue: 237/255)
    static let ink   = Color(red: 0.11, green: 0.12, blue: 0.14)
    static let mist  = Color(red: 0.11, green: 0.12, blue: 0.14).opacity(0.42)
    static let hair  = Color(red: 0.11, green: 0.12, blue: 0.14).opacity(0.16)

    static let line: CGFloat = 0.75

    static func mono(_ size: CGFloat = 10) -> Font { .system(size: size, weight: .regular, design: .monospaced) }
}

extension View {
    func label(_ size: CGFloat = 10, _ color: Color = SF.ink) -> some View {
        font(SF.mono(size)).foregroundStyle(color)
    }
}

func hashSeed(_ s: String) -> Double {
    Double(s.unicodeScalars.reduce(7) { ($0 &* 31 &+ Int($1.value)) % 9973 })
}

func ease(_ x: Double) -> Double { let x = min(max(x, 0), 1); return 1 - pow(1 - x, 3) }

func ring(_ c: CGPoint, _ r: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
}

struct Paper: View {
    var body: some View { SF.paper.ignoresSafeArea() }
}
