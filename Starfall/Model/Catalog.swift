import SwiftUI

/// The five energies every soul is made of. Each has a colour and a Bauhaus glyph.
enum Element: String, Codable, CaseIterable, Identifiable {
    case ember, tide, grove, sol, aether
    var id: String { rawValue }
    var name: String { rawValue.capitalized }

    var rgb: SIMD3<Double> {
        switch self {
        case .ember:  return [255, 128, 84] / 255
        case .tide:   return [60, 135, 237] / 255
        case .grove:  return [62, 196, 152] / 255
        case .sol:    return [247, 194, 88] / 255
        case .aether: return [150, 116, 255] / 255
        }
    }
    var color: Color { Color(red: rgb.x, green: rgb.y, blue: rgb.z) }

    var meaning: String {
        switch self {
        case .ember:  return "fire · will · motion"
        case .tide:   return "water · feeling · care"
        case .grove:  return "earth · ground · growth"
        case .sol:    return "light · joy · making"
        case .aether: return "spirit · mind · mystery"
        }
    }
}

enum Realm: String, Codable { case interest, trait, value }

/// A single interest or value in the catalogue.
struct Facet: Identifiable, Hashable {
    let id: String
    let name: String
    let element: Element
    let realm: Realm
    /// For interests: the value it is rooted in (and ascends into).
    let root: String?
    let line: String
}

/// A trait is a polarity, not a quantity: you sit somewhere between two poles.
struct Polarity: Identifiable, Hashable {
    let id: String
    let left: String
    let right: String
    /// true  → souls mend when close on this axis.
    /// false → souls mend through *difference* (a little), clash at full opposition.
    let harmonic: Bool
}

enum Catalog {
    // MARK: Values — what you hold.
    static let values: [Facet] = [
        v("presence", "Presence", .grove,  "To be fully here."),
        v("growth",   "Growth",   .grove,  "Becoming, slowly."),
        v("kindness", "Kindness", .tide,   "Gentleness as strength."),
        v("kinship",  "Kinship",  .tide,   "Your people, your table."),
        v("freedom",  "Freedom",  .ember,  "Open road, open sky."),
        v("courage",  "Courage",  .ember,  "Toward what scares you."),
        v("beauty",   "Beauty",   .sol,    "Moved by form and sound."),
        v("craft",    "Craft",    .sol,    "Making things, well."),
        v("play",     "Play",     .sol,    "Lightness as a practice."),
        v("wonder",   "Wonder",   .aether, "Awe at what is."),
        v("truth",    "Truth",    .aether, "Seeing clearly."),
        v("spirit",   "Spirit",   .aether, "Something larger."),
    ]

    // MARK: Interests — what you do. Each is rooted in a value.
    static let interests: [Facet] = [
        i("hiking", "Hiking", "presence"), i("sauna", "Sauna & Cold", "presence"),
        i("yoga", "Yoga", "presence"), i("swimming", "Swimming", "presence"),
        i("gardening", "Gardening", "growth"), i("languages", "Languages", "growth"),
        i("journaling", "Journaling", "growth"), i("strength", "Strength", "growth"),
        i("volunteering", "Volunteering", "kindness"), i("animals", "Animals", "kindness"),
        i("cooking", "Cooking", "kinship"), i("dinners", "Long Dinners", "kinship"),
        i("travel", "Travel", "freedom"), i("surfing", "Surfing", "freedom"),
        i("running", "Running", "freedom"), i("cycling", "Cycling", "freedom"),
        i("climbing", "Climbing", "courage"), i("martial", "Martial Arts", "courage"),
        i("music", "Music", "beauty"), i("art", "Art", "beauty"),
        i("architecture", "Architecture", "beauty"), i("fashion", "Fashion", "beauty"),
        i("making_music", "Making Music", "craft"), i("hardware", "Hardware", "craft"),
        i("coding", "Coding", "craft"), i("woodwork", "Woodwork", "craft"),
        i("dancing", "Dancing", "play"), i("gaming", "Gaming", "play"),
        i("sport", "Sport", "play"), i("comedy", "Comedy", "play"),
        i("astronomy", "Astronomy", "wonder"), i("photography", "Photography", "wonder"),
        i("film", "Film", "wonder"),
        i("reading", "Reading", "truth"), i("philosophy", "Philosophy", "truth"),
        i("science", "Science", "truth"),
        i("meditation", "Meditation", "spirit"), i("breathwork", "Breathwork", "spirit"),
    ]

    // MARK: Traits — how you are.
    static let traits: [Polarity] = [
        Polarity(id: "pace",    left: "Stillness", right: "Motion",   harmonic: true),
        Polarity(id: "social",  left: "Solitude",  right: "Communion", harmonic: false),
        Polarity(id: "gaze",    left: "Earth",     right: "Sky",      harmonic: false),
        Polarity(id: "hours",   left: "Dawn",      right: "Dusk",     harmonic: true),
        Polarity(id: "fire",    left: "Hearth",    right: "Wildfire", harmonic: true),
        Polarity(id: "compass", left: "Heart",     right: "Mind",     harmonic: false),
    ]

    static let byID: [String: Facet] = Dictionary(uniqueKeysWithValues: (values + interests).map { ($0.id, $0) })
    static func facet(_ id: String) -> Facet? { byID[id] }
    static func interests(rootedIn value: String) -> [Facet] { interests.filter { $0.root == value } }

    private static func v(_ id: String, _ n: String, _ e: Element, _ l: String) -> Facet {
        Facet(id: id, name: n, element: e, realm: .value, root: nil, line: l)
    }
    private static func i(_ id: String, _ n: String, _ root: String) -> Facet {
        let rootFacet = values.first { $0.id == root }!
        return Facet(id: id, name: n, element: rootFacet.element, realm: .interest, root: root,
                     line: "Rooted in \(rootFacet.name.lowercased()).")
    }
}
