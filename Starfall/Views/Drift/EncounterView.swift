import SwiftUI
import simd

/// Two attractors, coupled by how much you resonate.
/// Mend: the trajectories fall into step. Clash: each stays its own chaos.
struct EncounterView: View {
    var me: Soul
    var other: Soul
    var res: Resonance
    var onChoice: (BondRecord.Choice) -> Void

    @State private var system: CoupledLorenz
    @State private var born = Date()

    init(me: Soul, other: Soul, res: Resonance, onChoice: @escaping (BondRecord.Choice) -> Void) {
        self.me = me; self.other = other; self.res = res; self.onChoice = onChoice
        _system = State(initialValue: CoupledLorenz(me.lorenz, other.lorenz, k: max(0, res.score - 0.2) * 14))
    }

    var body: some View {
        ZStack {
            Paper()
            VStack(spacing: 0) {
                Spacer(minLength: 40)
                TimelineView(.animation) { tl in
                    Canvas { ctx, size in
                        system.advance()
                        let t = tl.date.timeIntervalSince(born)
                        draw(&ctx, size: size, yaw: me.lorenz.yaw + t * 0.04)
                    }
                }
                .frame(height: 380)
                .padding(.horizontal, 24)
                VStack(spacing: 8) {
                    Text(other.name.lowercased()).label(13)
                    Text(([res.meeting.rawValue] + res.sharedValues.prefix(3).compactMap { Catalog.facet($0)?.name.lowercased() })
                        .joined(separator: "  ·  ")).label(9, SF.mist)
                }
                .padding(.top, 22)
                Spacer()
                DualSlot(onLeft: { onChoice(.released) },
                         onRight: { Resonator.shared.play(.mend); onChoice(.bonded) })
                    .padding(.horizontal, 36)
                    .padding(.bottom, 24)
            }
        }
    }

    private func draw(_ ctx: inout GraphicsContext, size: CGSize, yaw: Double) {
        let s = min(size.width / 50, size.height / 54)
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        func proj(_ p: SIMD3<Double>) -> CGPoint {
            let q = Lorenz.project(p, yaw: yaw, pitch: 0, zMid: 25)
            return CGPoint(x: c.x + q.x * s, y: c.y + q.y * s)
        }
        stroke(&ctx, system.trailB, proj, color: SF.ink, peak: 0.55)
        stroke(&ctx, system.trailA, proj, color: SF.blue, peak: 0.95)
        ctx.fill(ring(proj(system.b), 2.5), with: .color(SF.ink))
        ctx.fill(ring(proj(system.a), 2.5), with: .color(SF.blue))
    }

    private func stroke(_ ctx: inout GraphicsContext, _ pts: [SIMD3<Double>], _ proj: (SIMD3<Double>) -> CGPoint,
                        color: Color, peak: Double) {
        guard pts.count > 2 else { return }
        let chunks = 8, per = max(1, pts.count / chunks)
        for k in 0..<chunks {
            let s = k * per, e = min(pts.count - 1, s + per + 1)
            guard e > s else { continue }
            var p = Path(); p.move(to: proj(pts[s]))
            for i in (s + 1)...e { p.addLine(to: proj(pts[i])) }
            ctx.stroke(p, with: .color(color.opacity(peak * (0.1 + 0.9 * Double(k + 1) / Double(chunks)))), lineWidth: SF.line)
        }
    }
}
