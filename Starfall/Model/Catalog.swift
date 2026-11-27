import SwiftUI

/// The five energies every soul is made of. Each has a colour and a Bauhaus glyph.
enum Element: String, Codable, CaseIterable, Identifiable {
    case ember, tide, grove, sol, aether
    var id: String { rawValue }
    var name: String { rawValue.capitalized }

    var rgb: SIMD3<Double> {
        switch self {
        // Orbit palette: coral, blue, orange, yellow, lavender.
        case .ember:  return [238, 78, 43] / 255
        case .tide:   return [60, 147, 216] / 255
        case .grove:  return [245, 139, 44] / 255
        case .sol:    return [243, 192, 42] / 255
        case .aether: return [158, 162, 220] / 255
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
/// Each pole belongs to an energy, so where you sit decides which colours you are made of.
struct Polarity: Identifiable, Hashable {
    let id: String
    let left: String
    let right: String
    let leftEnergy: Element
    let rightEnergy: Element
    /// true  → souls mend when close on this axis.
    /// false → souls mend through *difference* (a little), clash at full opposition.
    let harmonic: Bool
}

/// How someone takes part in an interest: watching it, doing it, or both.
enum Engagement: String, Codable, CaseIterable {
    case watch, play, both
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

    // MARK: Traits — your nature. Principles that run under every interest.
    static let traits: [Polarity] = [
        Polarity(id: "social",  left: "Introvert",    right: "Extrovert",   leftEnergy: .tide,   rightEnergy: .ember,  harmonic: false),
        Polarity(id: "tempo",   left: "Haste",        right: "Concentration", leftEnergy: .ember, rightEnergy: .aether, harmonic: true),
        Polarity(id: "time",    left: "Progress",     right: "Tradition",   leftEnergy: .sol,    rightEnergy: .grove,  harmonic: true),
        Polarity(id: "volume",  left: "Quiet",        right: "Loud",        leftEnergy: .tide,   rightEnergy: .ember,  harmonic: true),
        Polarity(id: "order",   left: "Discipline",   right: "Freedom",     leftEnergy: .grove,  rightEnergy: .sol,    harmonic: false),
        Polarity(id: "craft",   left: "Mathematical", right: "Artistic",    leftEnergy: .aether, rightEnergy: .sol,    harmonic: false),
        Polarity(id: "seat",    left: "Mind",         right: "Body",        leftEnergy: .aether, rightEnergy: .grove,  harmonic: true),
        Polarity(id: "stance",  left: "Observe",      right: "Partake",     leftEnergy: .tide,   rightEnergy: .grove,  harmonic: false),
        Polarity(id: "risk",    left: "Comfort",      right: "Adventure",   leftEnergy: .grove,  rightEnergy: .ember,  harmonic: true),
        Polarity(id: "reach",   left: "Depth",        right: "Breadth",     leftEnergy: .aether, rightEnergy: .sol,    harmonic: false),
        Polarity(id: "edge",    left: "Gentle",       right: "Competitive", leftEnergy: .tide,   rightEnergy: .ember,  harmonic: true),
    ]
    static func trait(_ id: String) -> Polarity? { traits.first { $0.id == id } }

    // MARK: Specifics — what each interest means to you, one level down.
    static let specifics: [String: [String]] = [
        "sport": ["Hockey", "Soccer", "Basketball", "Football", "Baseball", "Tennis", "Golf", "Formula 1"],
        "music": ["Jazz", "Hip-hop", "Electronic", "Indie", "Classical", "R&B", "Rock"],
        "making_music": ["Guitar", "Piano", "Synths", "Drums", "Production", "Singing"],
        "gaming": ["Shooters", "Strategy", "RPGs", "Sim racing", "Indie games", "Board games"],
        "film": ["Sci-fi", "Horror", "Documentary", "Anime", "Arthouse", "Comedy"],
        "reading": ["Fiction", "Sci-fi", "History", "Biography", "Poetry"],
        "cooking": ["Baking", "Ramen", "BBQ", "Plant-based", "Fermenting", "Pasta"],
        "dinners": ["Hosting", "Restaurants", "Wine", "Supper clubs"],
        "travel": ["Road trips", "City breaks", "Backpacking", "Slow travel"],
        "art": ["Painting", "Illustration", "Sculpture", "Galleries", "Street art"],
        "hiking": ["Day hikes", "Backcountry", "Peaks"],
        "running": ["5K", "Marathon", "Trail"],
        "cycling": ["Road", "Gravel", "Mountain", "Commuting"],
        "climbing": ["Bouldering", "Sport", "Trad"],
        "swimming": ["Pool", "Open water", "Diving"],
        "photography": ["Film cameras", "Street", "Portraits", "Landscape"],
        "coding": ["Web", "iOS", "AI", "Games"],
        "hardware": ["Microcontrollers", "PCB design", "Synth DIY", "Robotics"],
        "dancing": ["Salsa", "House", "Ballet", "Swing", "Hip-hop"],
        "martial": ["Boxing", "BJJ", "Muay Thai", "Karate"],
        "fashion": ["Streetwear", "Vintage", "Tailoring"],
        "comedy": ["Stand-up", "Improv", "Sketch"],
        "science": ["Physics", "Biology", "Space"],
        "astronomy": ["Stargazing", "Astrophotography"],
        "strength": ["Powerlifting", "Calisthenics", "CrossFit"],
        "surfing": ["Shortboard", "Longboard"],
    ]
    /// Interests you can either watch or do, with the words for each.
    static let engagement: [String: (watch: String, play: String)] = [
        "sport": ("Watch", "Play"), "music": ("Listen", "Play"), "gaming": ("Watch", "Play"),
        "film": ("Watch", "Make"), "art": ("Admire", "Make"), "dancing": ("Watch", "Dance"),
        "cooking": ("Eat", "Cook"), "dinners": ("Go to", "Host"), "fashion": ("Follow", "Wear"),
        "comedy": ("Watch", "Perform"), "architecture": ("Visit", "Design"), "photography": ("Look", "Shoot"),
        "martial": ("Watch", "Train"), "surfing": ("Watch", "Surf"),
    ]
    static func engagementWord(_ id: String, _ e: Engagement) -> String? {
        guard let w = engagement[id] else { return nil }
        switch e {
        case .watch: return w.watch
        case .play: return w.play
        case .both: return "\(w.watch) and \(w.play.lowercased())"
        }
    }

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
