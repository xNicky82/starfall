import SwiftUI
import QuartzCore
import UIKit
import Observation

/// Orbit colours for the five energies. Index order matches `Element.allCases`.
enum OrbPalette {
    static var rgb: [SIMD3<Float>] { Element.allCases.map { SIMD3(Float($0.rgb.x), Float($0.rgb.y), Float($0.rgb.z)) } }
    static var flat: [Float] { rgb.flatMap { [$0.x, $0.y, $0.z] } }
    static let ground = Color(red: 0.843, green: 0.843, blue: 0.835)
    static let ink = Color(red: 0.039, green: 0.039, blue: 0.047)
    static let ink2 = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let paper = Color(red: 0.96, green: 0.96, blue: 0.953)
    static let muted = Color(red: 0.43, green: 0.43, blue: 0.45)
    static let hair = Color.black.opacity(0.09)
}

extension Element {
    var index: Int { Element.allCases.firstIndex(of: self) ?? 0 }
}

enum OrbitTab: Int, CaseIterable, Identifiable {
    case friends, home, inbox, profile
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .friends: return "Friends"
        case .home: return "Home"
        case .inbox: return "Inbox"
        case .profile: return "Profile"
        }
    }
    var symbol: String {
        switch self {
        case .friends: return "person.2"
        case .home: return "house"
        case .inbox: return "bubble.left"
        case .profile: return "person.crop.circle"
        }
    }
}

struct OrbMessage: Identifiable, Hashable {
    let id = UUID()
    /// nil = you
    var from: UUID?
    var text: String
}

struct OrbThread: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var members: [UUID]
    var time: String
    var unread: Bool
    var msgs: [OrbMessage]
}

enum OrbitSheet: Equatable { case person(UUID), read }

/// Drives the frame clock (CADisplayLink) for the field.
final class FrameTicker: NSObject {
    private var link: CADisplayLink?
    var onFrame: ((CFTimeInterval) -> Void)?
    func start() {
        guard link == nil else { return }
        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        l.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        l.add(to: .main, forMode: .common)
        link = l
    }
    func stop() { link?.invalidate(); link = nil }
    @objc private func tick(_ l: CADisplayLink) { onFrame?(l.targetTimestamp) }
}

/// Everything Orbit needs: one persistent field, the tab state, the inbox.
/// Tabs never navigate; they only move orbs and swap the thin layer of UI on top.
@Observable
final class Orbit {
    // MARK: UI state (observed)
    var tab: OrbitTab = UserDefaults.standard.string(forKey: "orbitTab").flatMap(Int.init).flatMap(OrbitTab.init(rawValue:)) ?? .home // launch arg `-orbitTab 0..3`
    var sheet: OrbitSheet?
    var threadID: UUID?
    var threads: [OrbThread] = []
    var homeField: [UUID] = []
    var homeQueue: [UUID] = []
    var toast: String?
    var frame = 0
    /// Keyboard height in points, so the composer can ride above it.
    var keyboard: CGFloat = 0
    /// Profile: the details sheet (photo, age, location...).
    var showDetails = false
    /// Onboarding: your orb is made in the field, before any tab exists.
    var attuning = false

    // MARK: Field (not observed; `frame` ticks instead)
    @ObservationIgnored let engine: OrbEngine
    @ObservationIgnored private(set) var me: Soul
    @ObservationIgnored let others: [Soul]
    @ObservationIgnored private let store: Store
    @ObservationIgnored var size: CGSize = .zero
    @ObservationIgnored var insets = EdgeInsets()
    @ObservationIgnored var displayScale: CGFloat = 3
    @ObservationIgnored var reduceMotion = false
    @ObservationIgnored var U: Double = 390
    @ObservationIgnored var zoom = 1.0
    @ObservationIgnored var targetZoom = 1.0
    @ObservationIgnored var time = 0.0
    @ObservationIgnored var avatarFrames: [String: CGRect] = [:]
    @ObservationIgnored var cardHeight: CGFloat = 0
    @ObservationIgnored private let ticker = FrameTicker()
    @ObservationIgnored private var last: CFTimeInterval?
    @ObservationIgnored private var resCache: [String: Resonance] = [:]

    // MARK: Tab orb (bar-local points)
    @ObservationIgnored var barWidth: CGFloat = 0
    @ObservationIgnored var tabX: Double = 0
    @ObservationIgnored var tabV: Double = 0
    @ObservationIgnored var tabMorph: Double = 1
    @ObservationIgnored var tabTrail: Double = 0
    @ObservationIgnored private var tabPlaced = false

    static let maxHome = 4
    static let maxOrbs = 16

    init(store: Store) {
        self.store = store
        self.me = store.me ?? Soul(name: "You")
        self.others = store.others
        var cache: [String: Resonance] = [:]
        let like: OrbEngine.Likeness = { a, b in
            let key = a.id.uuidString < b.id.uuidString ? a.id.uuidString + b.id.uuidString : b.id.uuidString + a.id.uuidString
            let r: Resonance
            if let c = cache[key] { r = c } else { r = Resonance.between(a, b); cache[key] = r }
            let ea = a.elements, eb = b.elements
            let shared = Element.allCases.map { min(ea[$0] ?? 0, eb[$0] ?? 0) }
            return (Orbit.sim(r.score), shared)
        }
        engine = OrbEngine(like: like)
        engine.add(me, r: Orbit.radius(of: me, isMe: true), anchor: true)
        homeQueue = nearby.map(\.id)
        homeField = Array(homeQueue.prefix(2))
        homeQueue.removeAll { homeField.contains($0) }
        threads = Orbit.seedThreads(friends: friends)
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { [weak self] n in
            guard let self, let end = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let h = max(0, (self.size.height > 0 ? self.size.height : end.maxY) - end.minY)
            withAnimation(.easeOut(duration: 0.25)) { self.keyboard = h }
        }
        engine.onTouch = { [weak self] p in
            guard let self else { return }
            let other = p.a.anchor ? p.b.soul : p.a.soul
            Resonator.shared.play(.meeting(self.resonance(self.me, other).meeting))
        }
    }

    // MARK: People

    /// Bonded souls first, then the demo field fills the rest (until real people exist).
    var friends: [Soul] {
        let bonded = store.bonded.compactMap { store.soul($0.soulID) }
        var out = bonded
        for s in others where out.count < 12 && !out.contains(where: { $0.id == s.id }) { out.append(s) }
        return Array(out.prefix(Orbit.maxOrbs - 2))
    }
    var nearby: [Soul] {
        let f = Set(friends.map(\.id))
        return Array(others.filter { !f.contains($0.id) }.prefix(6))
    }
    func soul(_ id: UUID) -> Soul? { id == me.id ? me : others.first { $0.id == id } }

    func resonance(_ a: Soul, _ b: Soul) -> Resonance {
        let key = a.id.uuidString < b.id.uuidString ? a.id.uuidString + b.id.uuidString : b.id.uuidString + a.id.uuidString
        if let r = resCache[key] { return r }
        let r = Resonance.between(a, b); resCache[key] = r; return r
    }
    /// Resonance score mapped onto the 0…1 range the physics was tuned for.
    static func sim(_ score: Double) -> Double { min(1, max(0, (score - 0.2) / 0.45)) }
    static func radius(of s: Soul, isMe: Bool = false) -> Double {
        isMe ? 0.145 : 0.084 + Double(min(s.interests.count, 8)) * 0.004
    }
    func pct(_ s: Soul) -> Int { Int((resonance(me, s).score * 100).rounded()) }
    func distance(_ s: Soul) -> String { "\(40 + Int(hashSeed(s.name)) % 280) m" }
    func dominant(_ s: Soul) -> Element { s.aura.first?.0 ?? .tide }

    // MARK: Lifecycle

    func start() {
        ticker.onFrame = { [weak self] ts in self?.tick(ts) }
        ticker.start()
    }
    func stop() { ticker.stop() }

    func setScreen(size: CGSize, insets: EdgeInsets, scale: CGFloat) {
        let changed = size != self.size
        self.size = size; self.insets = insets; displayScale = scale
        U = Double(min(size.width, size.height * 0.7))
        if changed { apply() }
    }

    /// Your soul changed (Essence editor): swap it under the orb without a jump.
    func refreshMe() {
        guard let m = store.me else { return }
        me = m
        resCache = [:]
        engine.replace(m.id, with: m)
        apply()
    }

    private func tick(_ ts: CFTimeInterval) {
        let dt = min(0.05, ts - (last ?? ts - 1.0 / 60))
        last = ts
        time += reduceMotion ? dt * 0.3 : dt
        zoom += (targetZoom - zoom) * (1 - exp(-dt * 3.2))
        engine.wander = reduceMotion ? 0.003 : 0.012
        engine.step(dt)
        stepTabOrb(dt)
        frame &+= 1
    }

    // MARK: Camera

    func toScreen(_ x: Double, _ y: Double) -> CGPoint {
        let w = Double(size.width), h = Double(size.height)
        return CGPoint(x: w / 2 + x * U * zoom, y: h / 2 + y * U * zoom)
    }
    func toWorld(_ p: CGPoint, zoom z: Double? = nil) -> SIMD2<Double> {
        let z = z ?? zoom
        let px = Double(p.x) - Double(size.width) / 2, py = Double(p.y) - Double(size.height) / 2
        return SIMD2<Double>(px / (U * z), py / (U * z))
    }
    var barTop: CGFloat { size.height - insets.bottom - 10 - 62 }
    var headerBottom: CGFloat {
        switch tab {
        case .home: return insets.top + 12
        case .friends: return insets.top + 76
        default: return insets.top + 76
        }
    }

    private func setFieldRegion(_ z: Double) {
        let top = headerBottom + 30, bottom = barTop - 40
        let tl = toWorld(CGPoint(x: 0, y: top), zoom: z), br = toWorld(CGPoint(x: size.width, y: bottom), zoom: z)
        engine.rect = (l: tl.x + 0.02 / z, t: tl.y, r: br.x - 0.02 / z, b: br.y)
        var cyPx = (top + bottom) / 2
        if sheet != nil, cardHeight > 0 {
            let sheetTop = barTop - 10 - cardHeight
            cyPx = (top + min(bottom, sheetTop - 20)) / 2
        }
        engine.cx = 0
        engine.cy = toWorld(CGPoint(x: 0, y: cyPx), zoom: z).y
    }

    // MARK: Scenes

    private struct Target { let soul: Soul; let r: Double; var pin: SIMD2<Double>? = nil; var at: SIMD2<Double>? = nil }

    private func scene(_ targets: [Target]) {
        let want = Set(targets.map(\.soul.id))
        for o in engine.orbs where !o.anchor && !want.contains(o.id) { engine.remove(o.id) }
        for t in targets {
            let o = engine.add(t.soul, r: t.r, at: t.at)
            o.tr = t.r; o.pin = t.pin
        }
    }

    func select(_ t: OrbitTab) {
        guard size != .zero else { tab = t; return }
        if t == tab && t == .inbox && threadID != nil { threadID = nil }
        if t != tab { Resonator.shared.play(.snap) }
        sheet = nil
        if t != .inbox { threadID = nil }
        tab = t
        apply()
    }

    /// Put the field into the arrangement for the current tab.
    func apply() {
        guard size != .zero, let you = engine.get(me.id) else { return }
        you.forceBand = nil; you.pin = nil; you.tr = Orbit.radius(of: me, isMe: true)
        engine.gather = 0.05
        if attuning { pinProfile(you); return }
        switch tab {
        case .home:
            targetZoom = 1; setFieldRegion(1)
            scene(homeField.compactMap { soul($0) }.map { Target(soul: $0, r: Orbit.radius(of: $0)) })
        case .friends:
            let z = min(0.56, Double(size.width) / U * 0.5)
            targetZoom = z; engine.gather = 0.45; setFieldRegion(z)
            scene(friends.map { Target(soul: $0, r: Orbit.radius(of: $0)) })
        case .inbox:
            targetZoom = 1
            pinInbox()
        case .profile:
            pinProfile(you)
        }
    }
    /// Your orb alone, enlarged at the top with every band fanned upward.
    private func pinProfile(_ you: Orb) {
        targetZoom = 1
        scene([])
        let rPx = min(86, Orbit.radius(of: me, isMe: true) * 1.35 * U)
        let cyPx = orbTop + rPx
        you.tr = rPx / U
        you.pin = SIMD2(0, toWorld(CGPoint(x: 0, y: cyPx), zoom: 1).y)
        you.forceBand = SIMD2(0, -1)
    }
    /// Onboarding finished: open the field on Home.
    func finishAttune() {
        store.attuned = true
        attuning = false
        tab = .home
        Resonator.shared.play(.mend)
        apply()
    }
    /// Top of your enlarged orb on Profile and during onboarding: clear of the header's title and subtitle,
    /// leaving room for the bands that fan out above it.
    var orbTop: CGFloat { insets.top + 110 }
    var profilePanelTop: CGFloat {
        let rPx = min(86, Orbit.radius(of: me, isMe: true) * 1.35 * U)
        return orbTop + rPx * 2 + 26
    }

    /// Inbox: each thread's people sit as an overlapping cluster in the row's avatar slot.
    func pinInbox() {
        guard tab == .inbox, let you = engine.get(me.id) else { return }
        var targets: [Target] = []
        var slots: [(OrbThread, String)] = []
        if let id = threadID, let t = threads.first(where: { $0.id == id }) {
            slots = [(t, "header")]
        } else {
            for t in threads.prefix(5) { slots.append((t, t.id.uuidString)) }
        }
        for (t, key) in slots {
            guard let f = avatarFrames[key] else { continue }
            let L = Orbit.cluster(t.members.count)
            for (i, id) in t.members.prefix(4).enumerated() {
                guard !targets.contains(where: { $0.soul.id == id }), let s = soul(id) else { continue }
                let o = L.pts[i]
                let w = toWorld(CGPoint(x: f.midX + o.x, y: f.midY + o.y), zoom: 1)
                targets.append(Target(soul: s, r: L.r / U, pin: w))
            }
        }
        scene(targets)
        you.tr = 22 / U
        you.pin = toWorld(CGPoint(x: size.width - 16 - 24, y: insets.top + 34), zoom: 1)
    }
    static func cluster(_ n: Int) -> (r: Double, pts: [CGPoint]) {
        switch n {
        case 1: return (26, [.zero])
        case 2: return (19, [CGPoint(x: -10, y: -6), CGPoint(x: 10, y: 6)])
        case 3: return (16, [CGPoint(x: -11, y: 7), CGPoint(x: 11, y: 7), CGPoint(x: 0, y: -11)])
        default: return (14, [CGPoint(x: -11, y: -10), CGPoint(x: 11, y: -10), CGPoint(x: -11, y: 10), CGPoint(x: 11, y: 10)])
        }
    }

    // MARK: Interactions

    func tapOrb(_ o: Orb) {
        if attuning { return }
        if o.anchor { if tab == .profile { showDetails = true } else { select(.profile) }; return }
        switch tab {
        case .home, .friends:
            if sheet == .person(o.id) { closeSheet() } else { open(.person(o.id)) }
        case .inbox:
            if let t = threads.first(where: { $0.members.contains(o.id) }) { openThread(t.id) }
        case .profile: showDetails = true
        }
    }
    func open(_ s: OrbitSheet) { sheet = s; Resonator.shared.play(.tick) }
    func closeSheet() { sheet = nil; cardHeight = 0; refreshRegion() }
    func refreshRegion() { if tab == .home || tab == .friends { setFieldRegion(targetZoom) } }

    /// Home: pull a nearby soul in from its corner glow.
    func pullIn(_ id: UUID, from point: CGPoint) {
        guard homeField.count < Orbit.maxHome else { show("Pass on someone first to make room"); return }
        guard let s = soul(id) else { return }
        homeQueue.removeAll { $0 == id }
        homeField.append(id)
        let o = engine.add(s, r: Orbit.radius(of: s), at: toWorld(point))
        o.pin = nil
        open(.person(id))
    }
    func pass(_ id: UUID) {
        homeField.removeAll { $0 == id }
        homeQueue.append(id)
        engine.remove(id)
        if let s = soul(id) { store.record(s, choice: .released, resonance: resonance(me, s)) }
        closeSheet()
    }
    func sayHi(_ id: UUID) {
        guard let s = soul(id) else { return }
        let r = resonance(me, s)
        store.record(s, choice: .bonded, resonance: r)
        _ = startThread(with: id)
        Resonator.shared.play(.meeting(r.meeting))
        closeSheet()
        show("Sent to \(s.name). It's in your inbox.")
    }
    func message(_ id: UUID) {
        let t = startThread(with: id)
        select(.inbox)
        openThread(t.id)
    }
    @discardableResult
    func startThread(with id: UUID) -> OrbThread {
        if let i = threads.firstIndex(where: { $0.members == [id] }) {
            let t = threads.remove(at: i); threads.insert(t, at: 0); return t
        }
        let s = soul(id)
        let shared = s.map { resonance(me, $0).sharedInterests.compactMap { Catalog.facet($0)?.name } } ?? []
        let hello = shared.first.map { "Hey, saw we both love \($0.lowercased())." } ?? "Hey, we just crossed paths."
        let t = OrbThread(title: s?.name ?? "New", members: [id], time: "now", unread: false, msgs: [OrbMessage(from: nil, text: hello)])
        threads.insert(t, at: 0)
        threads = Array(threads.prefix(5))
        return t
    }
    func openThread(_ id: UUID) {
        threadID = id
        if let i = threads.firstIndex(where: { $0.id == id }) { threads[i].unread = false }
        Resonator.shared.play(.tick)
        pinInbox()
    }
    func closeThread() { threadID = nil; pinInbox() }
    func send(_ text: String) {
        let v = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !v.isEmpty, let id = threadID, let i = threads.firstIndex(where: { $0.id == id }) else { return }
        var t = threads.remove(at: i)
        t.msgs.append(OrbMessage(from: nil, text: v)); t.time = "now"
        threads.insert(t, at: 0)
        Resonator.shared.play(.tick)
    }
    func show(_ msg: String) {
        toast = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            if self?.toast == msg { self?.toast = nil }
        }
    }
    var hasUnread: Bool { threads.contains { $0.unread } }

    // MARK: Tab orb

    func tabCenter(_ t: OrbitTab) -> Double {
        let inner = Double(barWidth) - 8
        return 4 + inner / 4 * (Double(t.rawValue) + 0.5)
    }
    private func stepTabOrb(_ dt: Double) {
        guard barWidth > 0 else { return }
        let target = tabCenter(tab)
        if !tabPlaced { tabX = target; tabPlaced = true }
        let h = dt / 4
        for _ in 0..<4 {
            tabV += ((target - tabX) * 120 - tabV * 15) * h
            tabX += tabV * h
        }
        let moving = abs(tabV) > 25 || abs(target - tabX) > 2
        tabMorph += ((moving ? 0 : 1) - tabMorph) * (1 - exp(-dt * (moving ? 14 : 7)))
        tabTrail += (orbSmooth(30, 500, abs(tabV)) - tabTrail) * (1 - exp(-dt * (abs(tabV) > 30 ? 10 : 2.5)))
    }

    // MARK: Shader packing

    struct FieldUniforms { var n: Int; var orbs: [Float]; var offs: [Float]; var depth: [Float]; var nb: Int; var beads: [Float] }

    func fieldUniforms() -> FieldUniforms {
        let N = Orbit.maxOrbs
        var orbs = [Float](repeating: 0, count: N * 4)
        var offs = [Float](repeating: 0, count: N * 15)
        var depth = [Float](repeating: 0, count: 5)
        let order = engine.layerOrder()
        for (rank, c) in order.enumerated() { depth[c] = Float(rank) }
        let s = U * zoom
        let list = Array(engine.orbs.prefix(N))
        for (i, o) in list.enumerated() {
            let p = toScreen(o.x, o.y)
            orbs[i * 4] = Float(p.x); orbs[i * 4 + 1] = Float(p.y); orbs[i * 4 + 2] = Float(o.r * s)
            var cum = 0.0
            for c in order where o.has(c) {
                cum += o.rev[c] * o.amount(c) * 0.12 * o.r
                let k = (i * 5 + c) * 3
                offs[k] = Float(o.bd[c].x * cum * s); offs[k + 1] = Float(o.bd[c].y * cum * s); offs[k + 2] = 1
            }
        }
        let bs = engine.beads(palette: OrbPalette.rgb)
        var beads = [Float](repeating: 0, count: 8 * 9)
        for (k, b) in bs.enumerated() {
            let p = toScreen(b.x, b.y)
            let v: [Float] = [Float(p.x), Float(p.y), Float(b.intensity), Float(b.seed), Float(b.tx), Float(b.ty), b.color.x, b.color.y, b.color.z]
            for j in 0..<9 { beads[k * 9 + j] = v[j] }
        }
        return FieldUniforms(n: list.count, orbs: orbs, offs: offs, depth: depth, nb: bs.count, beads: beads)
    }

    /// Trail offsets for the tab orb: your energies smear out behind it as it slides.
    func tabUniforms() -> (offs: [Float], depth: [Float]) {
        let prof = Element.allCases.map { me.elements[$0] ?? 0 }
        let order = (0..<5).sorted { prof[$0] > prof[$1] }
        var offs = [Float](repeating: 0, count: 10), depth = [Float](repeating: 0, count: 5)
        let dir = tabV >= 0 ? -1.0 : 1.0
        var cum = 0.0
        for (rank, c) in order.enumerated() {
            depth[c] = Float(rank)
            guard prof[c] > 0.04 else { continue }
            cum += tabTrail * min(1, prof[c] * 2.5) * 5
            offs[c * 2] = Float(dir * cum)
        }
        return (offs, depth)
    }
    var tabStretch: Double { 1 + min(0.35, abs(tabV) / 2200) }

    // MARK: Demo inbox

    private static func seedThreads(friends f: [Soul]) -> [OrbThread] {
        guard f.count >= 11 else { return [] }
        func top(_ s: Soul) -> String { (s.activeInterests.max { $0.1 < $1.1 }?.0.name ?? "a walk").lowercased() }
        return [
            OrbThread(title: f[0].name, members: [f[0].id], time: "2m", unread: true, msgs: [
                OrbMessage(from: nil, text: "Are you around this week?"),
                OrbMessage(from: f[0].id, text: "Yes. \(top(f[0]).capitalized) on Thursday?")]),
            OrbThread(title: "Saturday crew", members: [f[1].id, f[2].id, f[3].id, f[4].id], time: "18m", unread: true, msgs: [
                OrbMessage(from: f[1].id, text: "Who is in for Saturday?"),
                OrbMessage(from: nil, text: "Me, if it ends somewhere with coffee"),
                OrbMessage(from: f[3].id, text: "Usual spot, 10am")]),
            OrbThread(title: f[5].name, members: [f[5].id], time: "1h", unread: false, msgs: [
                OrbMessage(from: f[5].id, text: "Found something for your \(top(f[5])) habit, want the link?")]),
            OrbThread(title: "Long dinners", members: [f[6].id, f[7].id], time: "3h", unread: false, msgs: [
                OrbMessage(from: f[6].id, text: "Thursday at mine again?"),
                OrbMessage(from: f[7].id, text: "Bringing dessert this time")]),
            OrbThread(title: "Old friends", members: [f[8].id, f[9].id, f[10].id], time: "Tue", unread: false, msgs: [
                OrbMessage(from: f[8].id, text: "Catching up Sunday?"),
                OrbMessage(from: f[10].id, text: "Sunday works, food after")]),
        ]
    }
}
