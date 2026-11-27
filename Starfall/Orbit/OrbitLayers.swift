import SwiftUI

// MARK: - Home: people around you appear as colour glows in the corners

struct HomeGlows: View {
    let orbit: Orbit

    var body: some View {
        let _ = orbit.frame
        let ids = Array(orbit.homeQueue.prefix(4))
        ZStack(alignment: .topLeading) {
            ForEach(Array(ids.enumerated()), id: \.element) { i, id in
                if let s = orbit.soul(id) {
                    let p = corner(i)
                    GlowSpot(name: s.name, distance: orbit.distance(s), color: orbit.dominant(s).color,
                             side: i % 2 == 0 ? 1 : -1, breathe: 1 + 0.05 * sin(orbit.time * 1.25 + Double(i) * 1.3))
                        .position(p)
                        .onTapGesture { orbit.pullIn(id, from: p) }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                        .transition(.opacity.combined(with: .scale(scale: 0.6)))
                }
            }
        }
        .frame(width: orbit.size.width, height: orbit.size.height, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.5), value: ids)
    }

    private func corner(_ i: Int) -> CGPoint {
        let w = orbit.size.width
        let top = orbit.insets.top + 64, bottom = orbit.barTop - 58
        switch i {
        case 0: return CGPoint(x: 26, y: top)
        case 1: return CGPoint(x: w - 26, y: top)
        case 2: return CGPoint(x: 26, y: bottom)
        default: return CGPoint(x: w - 26, y: bottom)
        }
    }
}

struct GlowSpot: View {
    let name: String
    let distance: String
    let color: Color
    /// +1 when the glow hugs the left edge, -1 for the right edge.
    let side: CGFloat
    let breathe: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [color, color.opacity(0.55), color.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: 85))
                .frame(width: 170, height: 170)
                .blur(radius: 14)
                .scaleEffect(breathe)
            VStack(spacing: 2) {
                Text(name).font(.system(size: 13, weight: .semibold))
                Text(distance).font(.system(size: 11.5, weight: .medium)).foregroundStyle(OrbPalette.ink.opacity(0.6))
            }
            .foregroundStyle(OrbPalette.ink)
            .offset(x: side * 38)
        }
        .frame(width: 170, height: 170)
        .contentShape(Circle().inset(by: 30))
    }
}

// MARK: - Friends: zoomed out, everyone you know and how they overlap

struct FriendsLayer: View {
    let orbit: Orbit

    var body: some View {
        OrbitHeader(orbit: orbit, title: "Friends",
                    subtitle: "\(orbit.friends.count) friends, and who would click") {
            Button {
                if orbit.sheet == .read { orbit.closeSheet() } else { orbit.open(.read) }
            } label: {
                Text("Read")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(OrbPalette.ink)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .glassCapsule()
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Inbox: orbs as avatars, clusters for groups

struct AvatarFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

private struct AvatarSlot: View {
    let key: String
    var body: some View {
        Color.clear.background(
            GeometryReader { g in
                Color.clear.preference(key: AvatarFrameKey.self, value: [key: g.frame(in: .global)])
            }
        )
    }
}

struct InboxLayer: View {
    let orbit: Orbit

    var body: some View {
        let unread = orbit.threads.filter(\.unread).count
        VStack(alignment: .leading, spacing: 0) {
            OrbitHeader(orbit: orbit, title: "Inbox", subtitle: unread > 0 ? "\(unread) unread" : "All caught up") {
                Color.clear.frame(width: 48, height: 48) // your orb tucks in here
            }
            Group {
                if let id = orbit.threadID, let t = orbit.threads.first(where: { $0.id == id }) {
                    ThreadPane(orbit: orbit, thread: t)
                } else {
                    rows
                }
            }
            .padding(.horizontal, max(16, orbit.insets.leading))
            .padding(.top, 10)
        }
        .frame(width: orbit.size.width, height: orbit.size.height, alignment: .topLeading)
        .onPreferenceChange(AvatarFrameKey.self) { frames in
            orbit.avatarFrames = frames
            orbit.pinInbox()
        }
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(orbit.threads.prefix(5)) { t in
                Button { orbit.openThread(t.id) } label: {
                    HStack(spacing: 14) {
                        AvatarSlot(key: t.id.uuidString).frame(width: 66, height: 64)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(t.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(OrbPalette.ink)
                            Text(preview(t))
                                .font(.system(size: 14.5, weight: t.unread ? .medium : .regular))
                                .foregroundStyle(t.unread ? OrbPalette.ink : OrbPalette.muted)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 8) {
                            Text(t.time).font(.system(size: 13)).foregroundStyle(OrbPalette.muted).monospacedDigit()
                            Circle().fill(t.unread ? Element.tide.color : .clear).frame(width: 9, height: 9)
                        }
                    }
                    .frame(minHeight: 78)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Rectangle().fill(OrbPalette.hair).frame(height: 0.5)
            }
        }
    }

    private func preview(_ t: OrbThread) -> String {
        guard let m = t.msgs.last else { return "" }
        if m.from == nil { return "You: " + m.text }
        if t.members.count > 1, let id = m.from, let s = orbit.soul(id) { return s.name + ": " + m.text }
        return m.text
    }
}

struct ThreadPane: View {
    let orbit: Orbit
    let thread: OrbThread
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { orbit.closeThread() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(OrbPalette.ink.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to inbox")
                AvatarSlot(key: "header").frame(width: 66, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(thread.title).font(.system(size: 17, weight: .semibold))
                    Text(subtitle).font(.system(size: 13)).foregroundStyle(OrbPalette.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(OrbPalette.ink)
            .padding(.bottom, 10)
            Rectangle().fill(OrbPalette.hair).frame(height: 0.5)

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(Array(thread.msgs.enumerated()), id: \.element.id) { i, m in
                            bubble(m, showName: m.from != nil && thread.members.count > 1 && (i == 0 || thread.msgs[i - 1].from != m.from))
                                .id(m.id)
                        }
                    }
                    .padding(.vertical, 14)
                }
                .onAppear { if let last = thread.msgs.last?.id { proxy.scrollTo(last, anchor: .bottom) } }
                .onChange(of: thread.msgs.count) { _, _ in
                    if let last = thread.msgs.last?.id { withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(last, anchor: .bottom) } }
                }
            }

            HStack(spacing: 8) {
                TextField("Message", text: $draft)
                    .font(.system(size: 16))
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .glassCapsule()
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(OrbPalette.paper)
                        .frame(width: 44, height: 44)
                        .background(OrbPalette.ink, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Send")
            }
            .padding(.top, 6)
            .padding(.bottom, bottomSpace)
        }
    }

    private var subtitle: String {
        if thread.members.count > 1 { return thread.members.compactMap { orbit.soul($0)?.name }.joined(separator: ", ") }
        guard let id = thread.members.first, let s = orbit.soul(id) else { return "" }
        return "\(orbit.pct(s))% resonance"
    }
    private var bottomSpace: CGFloat {
        let bar = orbit.size.height - orbit.barTop + 10
        return max(bar, orbit.keyboard + 8)
    }
    private func send() {
        orbit.send(draft)
        draft = ""
    }

    @ViewBuilder private func bubble(_ m: OrbMessage, showName: Bool) -> some View {
        let mine = m.from == nil
        HStack {
            if mine { Spacer(minLength: 60) }
            VStack(alignment: .leading, spacing: 3) {
                if showName, let id = m.from, let s = orbit.soul(id) {
                    Text(s.name).font(.system(size: 12, weight: .medium)).foregroundStyle(OrbPalette.muted).padding(.leading, 12)
                }
                Text(m.text)
                    .font(.system(size: 15.5))
                    .foregroundStyle(mine ? OrbPalette.paper : OrbPalette.ink)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(mine ? OrbPalette.ink : Color.white.opacity(0.72),
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            if !mine { Spacer(minLength: 60) }
        }
    }
}
