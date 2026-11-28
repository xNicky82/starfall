import SwiftUI
import UIKit

/// The whole app after Attune: one persistent orb field with a thin UI layer per tab on top.
struct OrbitRoot: View {
    @Environment(Store.self) private var store
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var orbit: Orbit?

    var body: some View {
        GeometryReader { g in
            ZStack {
                OrbPalette.ground
                if let orbit { OrbitStage(orbit: orbit) }
            }
            .frame(width: g.size.width, height: g.size.height)
            .onAppear {
                if store.me == nil { store.me = Soul(name: "") }
                let o = orbit ?? Orbit(store: store)
                o.attuning = !store.attuned
                o.reduceMotion = reduceMotion
                o.setScreen(size: g.size, insets: OrbitRoot.insets(g), scale: displayScale)
                o.start()
                orbit = o
            }
            .onDisappear { orbit?.stop() }
            .onChange(of: g.size) { _, s in orbit?.setScreen(size: s, insets: OrbitRoot.insets(g), scale: displayScale) }
            .onChange(of: reduceMotion) { _, v in orbit?.reduceMotion = v }
        }
        .ignoresSafeArea()
    }

    /// Safe-area insets even though the stage itself runs edge to edge.
    static func insets(_ g: GeometryProxy) -> EdgeInsets {
        let w = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
        let i = w?.safeAreaInsets ?? .zero
        let s = g.safeAreaInsets
        return EdgeInsets(top: max(i.top, s.top), leading: max(i.left, s.leading),
                          bottom: max(i.bottom, s.bottom), trailing: max(i.right, s.trailing))
    }
}

struct OrbitStage: View {
    let orbit: Orbit

    var body: some View {
        ZStack(alignment: .topLeading) {
            OrbField(orbit: orbit)
            OrbLabels(orbit: orbit)
            ProfilePhoto(orbit: orbit)

            Group {
                if orbit.attuning {
                    AttuneLayer(orbit: orbit)
                } else {
                    switch orbit.tab {
                    case .home: HomeGlows(orbit: orbit)
                    case .friends: FriendsLayer(orbit: orbit)
                    case .inbox: InboxLayer(orbit: orbit)
                    case .profile: ProfileLayer(orbit: orbit)
                    }
                }
            }
            .transition(.opacity.combined(with: .offset(y: 8)))
            .id(orbit.attuning ? -1 : orbit.tab.rawValue)

            OrbitCardHost(orbit: orbit)

            if let t = orbit.toast {
                Text(t)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(OrbPalette.ink)
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .glassCapsule()
                    .position(x: orbit.size.width / 2, y: orbit.barTop - 28)
                    .transition(.opacity.combined(with: .offset(y: 10)))
                    .allowsHitTesting(false)
            }

            if !orbit.attuning {
                OrbitTabBar(orbit: orbit)
                    .frame(maxWidth: 440)
                    .padding(.horizontal, max(16, orbit.insets.leading))
                    .frame(width: orbit.size.width)
                    .position(x: orbit.size.width / 2, y: orbit.barTop + 31)
                    .transition(.opacity.combined(with: .offset(y: 30)))
            }
        }
        .frame(width: orbit.size.width, height: orbit.size.height)
        .animation(.easeInOut(duration: 0.35), value: orbit.tab)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: orbit.sheet)
        .animation(.easeInOut(duration: 0.3), value: orbit.toast)
        .animation(.easeInOut(duration: 0.6), value: orbit.attuning)
    }
}

/// The Metal-drawn field. Re-renders every display frame.
struct OrbField: View {
    let orbit: Orbit
    @State private var track = DragTrack()

    var body: some View {
        let _ = orbit.frame
        let u = orbit.fieldUniforms()
        Rectangle()
            .fill(Color.white)
            .colorEffect(ShaderLibrary.orbField(
                .float(Float(orbit.displayScale)),
                .float(Float(orbit.time)),
                .float(Float(u.n)),
                .floatArray(u.orbs),
                .floatArray(u.offs),
                .floatArray(u.depth),
                .float(Float(u.nb)),
                .floatArray(u.beads),
                .floatArray(OrbPalette.flat)))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in track.changed(v, orbit) }
                    .onEnded { v in track.ended(v, orbit) }
            )
            .accessibilityHidden(true)
    }
}

/// Drag an orb through the goo; a short touch without movement is a tap.
final class DragTrack {
    private var orb: Orb?
    private var offset = SIMD2<Double>(0, 0)
    private var moved = false
    private var start = Date()
    private var active = false

    func changed(_ v: DragGesture.Value, _ orbit: Orbit) {
        if !active {
            active = true; moved = false; start = Date()
            let w = orbit.toWorld(v.startLocation)
            orb = orbit.engine.hit(w.x, w.y)
            if let o = orb { offset = SIMD2(o.x, o.y) - w }
        }
        if hypot(v.translation.width, v.translation.height) > 6 { moved = true }
        if moved, let o = orb, o.pin == nil, orbit.tab == .home || orbit.tab == .friends {
            o.grab = orbit.toWorld(v.location) + offset
        }
    }
    func ended(_ v: DragGesture.Value, _ orbit: Orbit) {
        orb?.grab = nil
        defer { active = false; orb = nil }
        guard !moved, Date().timeIntervalSince(start) < 0.5 else { return }
        if let o = orb { orbit.tapOrb(o) } else if orbit.sheet != nil { orbit.closeSheet() }
    }
}

/// Name pills under each orb on Home and Friends.
struct OrbLabels: View {
    let orbit: Orbit

    var body: some View {
        let _ = orbit.frame
        let show = !orbit.attuning && (orbit.tab == .home || orbit.tab == .friends)
        let compact = orbit.zoom < 0.8
        let sc = CGFloat(0.62 + 0.38 * min(1, orbit.zoom))
        ZStack(alignment: .topLeading) {
            ForEach(orbit.engine.orbs, id: \.id) { o in
                let k = CGFloat(o.tr > 0 ? min(1, o.r / o.tr) : 0)
                let p = orbit.toScreen(o.x, o.y + o.r)
                let visible = show && o.alive && o.pin == nil
                OrbPill(name: o.anchor ? "You" : o.soul.name,
                        pct: (o.anchor || compact) ? nil : orbit.pct(o.soul),
                        selected: orbit.sheet == .person(o.id))
                    .scaleEffect(sc * (0.6 + 0.4 * k), anchor: .top)
                    .position(x: p.x, y: p.y + 8 + 14 * sc)
                    .opacity(visible ? Double(max(0, (k - 0.3) / 0.7)) : 0)
            }
        }
        .frame(width: orbit.size.width, height: orbit.size.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}

struct OrbPill: View {
    let name: String
    let pct: Int?
    let selected: Bool

    var body: some View {
        let fg = selected ? OrbPalette.ink : OrbPalette.paper
        let bg = selected ? OrbPalette.paper : OrbPalette.ink
        HStack(spacing: 7) {
            Text(name).font(.system(size: 14, weight: .semibold))
            if let pct {
                Text("\(pct)%")
                    .font(.system(size: 12, weight: .semibold)).monospacedDigit()
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .foregroundStyle(bg)
                    .background(fg, in: Capsule())
            }
        }
        .foregroundStyle(fg)
        .padding(.leading, 12).padding(.trailing, pct == nil ? 12 : 5).padding(.vertical, 5)
        .background(bg, in: Capsule())
        .overlay(Capsule().strokeBorder(OrbPalette.ink, lineWidth: selected ? 1 : 0))
        .fixedSize()
    }
}

/// Large title + subtitle used by Friends, Inbox and Profile. Home has none.
struct OrbitHeader<Trailing: View>: View {
    let orbit: Orbit
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 32, weight: .bold)).tracking(-0.6)
                Text(subtitle).font(.system(size: 15)).foregroundStyle(OrbPalette.muted)
            }
            Spacer(minLength: 0)
            trailing()
        }
        .foregroundStyle(OrbPalette.ink)
        .padding(.top, orbit.insets.top + 6)
        .padding(.leading, max(16, orbit.insets.leading))
        .padding(.trailing, max(16, orbit.insets.trailing))
        .frame(width: orbit.size.width, alignment: .leading)
    }
}

// MARK: - Glass

extension View {
    /// Liquid Glass on iOS 26, a material capsule with a specular rim before that.
    @ViewBuilder func glassCapsule() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            self.modifier(GlassFallback())
        }
        #else
        self.modifier(GlassFallback())
        #endif
    }
}

struct GlassFallback: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: Capsule())
            .background(Capsule().fill(Color.white.opacity(0.22)))
            .overlay(
                Capsule().strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.25)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 0.75)
            )
            .shadow(color: .black.opacity(0.1), radius: 15, y: 8)
    }
}
