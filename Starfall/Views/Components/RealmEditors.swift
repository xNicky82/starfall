import SwiftUI

/// Tap circles to gather interests into your vessel.
struct InterestPicker: View {
    @Binding var soul: Soul
    private let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            ForEach(Element.allCases) { el in
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Glyph(element: el, size: 9)
                        Text(el.name).eyebrow(SF.ink.opacity(0.6))
                        Text(el.meaning).font(SF.body(11)).foregroundStyle(SF.mist)
                    }
                    LazyVGrid(columns: cols, spacing: 16) {
                        ForEach(Catalog.interests.filter { $0.element == el }) { f in
                            token(f)
                        }
                    }
                }
            }
        }
    }

    private func token(_ f: Facet) -> some View {
        let on = soul.interests[f.id] != nil
        return VStack(spacing: 7) {
            ZStack {
                Circle().fill(on ? AnyShapeStyle(RadialGradient(colors: [f.element.color.opacity(0.55), f.element.color],
                                                                 center: .topLeading, startRadius: 2, endRadius: 60))
                                 : AnyShapeStyle(Color.white.opacity(0.5)))
                Circle().stroke(on ? f.element.color : SF.faint, lineWidth: 1)
                if on { Circle().fill(.white).frame(width: 6, height: 6) }
            }
            .frame(width: 54, height: 54)
            .shadow(color: on ? f.element.color.opacity(0.45) : .clear, radius: 10)
            .scaleEffect(on ? 1 : 0.9)
            Text(f.name).font(SF.label(10.5)).foregroundStyle(on ? SF.ink : SF.mist)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .contentShape(Circle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { soul.toggleInterest(f.id) }
            Resonator.shared.play(.snap)
        }
    }
}

/// Weigh what you gathered. Push an interest into its slot and it becomes a value.
struct InterestWeigher: View {
    @Binding var soul: Soul
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(soul.activeInterests, id: \.0.id) { f, w in
                InterestSlider(facet: f, weight: w, limit: soul.interestLimit(f.id),
                               onChange: { soul.setInterest(f.id, $0) },
                               onAscend: { soul.ascend(f.id) })
                    .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .top).combined(with: .opacity)))
            }
            let asc = soul.ascended.compactMap(Catalog.facet).sorted { $0.name < $1.name }
            if !asc.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ascended — now part of who you are").eyebrow()
                    ForEach(asc) { f in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(f.element.color).frame(width: 30, height: 30)
                                    .shadow(color: f.element.color.opacity(0.5), radius: 8)
                                Image(systemName: "arrow.up").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.name).font(SF.display(15)).foregroundStyle(SF.ink)
                                Text("became \(Catalog.facet(f.root ?? "")?.name ?? "")").font(SF.body(12)).foregroundStyle(f.element.color)
                            }
                            Spacer()
                            // circle to return it to the world of interests
                            Circle().stroke(SF.faint).frame(width: 30, height: 30)
                                .overlay(Image(systemName: "arrow.down").font(.system(size: 11)).foregroundStyle(SF.mist))
                                .contentShape(Circle())
                                .onTapGesture { withAnimation(.spring()) { soul.descend(f.id) }; Resonator.shared.play(.snap) }
                        }
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 22).fill(SF.card))
            }
        }
    }
}

struct TraitsEditor: View {
    @Binding var soul: Soul
    var body: some View {
        VStack(spacing: 30) {
            ForEach(Catalog.traits) { p in
                PolaritySlider(polarity: p, value: soul.trait(p.id), tint: soul.hue) { soul.traits[p.id] = $0 }
            }
        }
    }
}

struct ValuesEditor: View {
    @Binding var soul: Soul
    var body: some View {
        VStack(spacing: 22) {
            ForEach(Catalog.values) { f in
                let feeders = Catalog.interests(rootedIn: f.id).filter { soul.interests[$0.id] != nil }
                    .map { soul.ascended.contains($0.id) ? "\($0.name) ↑" : $0.name }
                ValueSlider(facet: f, direct: soul.valueWeight(f.id), undercurrent: soul.undercurrent(into: f.id),
                            limit: soul.valueLimit(f.id), feeders: feeders) { soul.setValue(f.id, $0) }
            }
        }
    }
}

/// Health-app style stacked bar of a soul's elements.
struct ElementBar: View {
    var soul: Soul
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(soul.aura, id: \.0) { el, w in
                        Rectangle().fill(el.color).frame(width: max(2, geo.size.width * w - 2))
                    }
                }
            }
            .frame(height: 10)
            .clipShape(Capsule())
            HStack(spacing: 14) {
                ForEach(soul.aura.prefix(4), id: \.0) { el, w in
                    HStack(spacing: 5) {
                        Glyph(element: el, size: 8)
                        Text("\(el.name) \(Int((w * 100).rounded()))%").font(SF.label(10.5)).foregroundStyle(SF.mist)
                    }
                }
            }
        }
    }
}
