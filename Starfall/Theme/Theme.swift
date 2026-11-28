import SwiftUI

/// Brand colours that sit outside the Orbit palette.
enum SF {
    static let paper = Color(red: 233/255, green: 233/255, blue: 233/255)
    static let blue  = Color(red: 60/255,  green: 135/255, blue: 237/255)
}

func hashSeed(_ s: String) -> Double {
    Double(s.unicodeScalars.reduce(7) { ($0 &* 31 &+ Int($1.value)) % 9973 })
}
