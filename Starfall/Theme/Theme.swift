import SwiftUI

enum SF {
    static let blue  = Color(red: 60/255, green: 135/255, blue: 237/255)
    static let paper = Color(red: 233/255, green: 233/255, blue: 233/255)
    static let ember = Color(red: 1.0, green: 0.74, blue: 0.52)
    static let mist  = Color(red: 233/255, green: 233/255, blue: 233/255).opacity(0.42)
    static let faint = Color(red: 233/255, green: 233/255, blue: 233/255).opacity(0.12)

    static func type(_ size: CGFloat) -> Font { .custom("Futura-Medium", size: size) }
}

extension View {
    /// The one voice: small, uppercase, wide.
    func caption(_ size: CGFloat = 10, _ color: Color = SF.mist) -> some View {
        font(SF.type(size)).tracking(size * 0.3).textCase(.uppercase).foregroundStyle(color)
    }

    /// Prints the layer as a dithered night sky.
    func stipple(cell: CGFloat = 1.0, gain: Double = 1.15, specks: Double = 0, seed: Double = 0) -> some View {
        layerEffect(ShaderLibrary.stipple(.float(cell), .float(gain), .float(specks), .float(seed)),
                    maxSampleOffset: CGSize(width: cell, height: cell))
    }
}

func seed(_ s: String) -> Double {
    Double(s.unicodeScalars.reduce(7) { ($0 &* 31 &+ Int($1.value)) % 9973 })
}

func ease(_ x: Double) -> Double { let x = min(max(x, 0), 1); return 1 - pow(1 - x, 3) }

/// Black, with a scatter of faint stars.
struct Sky: View {
    var body: some View { Color.black.stipple(specks: 0.0035).ignoresSafeArea() }
}
