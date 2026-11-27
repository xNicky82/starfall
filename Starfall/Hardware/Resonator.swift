import Foundation
import CoreHaptics
import UIKit

/// One beat of vibration. `duration == 0` means a single tap (transient).
struct Beat: Codable, Hashable {
    var t: Double          // seconds from start
    var intensity: Float   // 0…1
    var sharpness: Float   // 0…1 (soft → crisp)
    var duration: Double = 0
}

/// A platform-neutral vibration pattern. The iPhone plays it through the Taptic Engine;
/// a Starfall pebble will receive the same score as bytes over BLE (see docs/HARDWARE.md).
struct VibrationScore: Codable, Hashable {
    var name: String
    var beats: [Beat]

    /// Wire format v0: [u8 count] then per beat [u16 t_ms][u8 intensity][u8 sharpness][u16 dur_ms], little-endian.
    func encoded() -> Data {
        var d = Data([UInt8(min(beats.count, 255))])
        for b in beats.prefix(255) {
            let t = UInt16(clamping: Int(b.t * 1000)), dur = UInt16(clamping: Int(b.duration * 1000))
            d.append(contentsOf: [UInt8(t & 0xff), UInt8(t >> 8),
                                  UInt8(b.intensity * 255), UInt8(b.sharpness * 255),
                                  UInt8(dur & 0xff), UInt8(dur >> 8)])
        }
        return d
    }

    // MARK: The vocabulary

    /// A heartbeat felt as another soul approaches.
    static func pulse(_ intensity: Float) -> VibrationScore {
        VibrationScore(name: "pulse", beats: [Beat(t: 0, intensity: intensity, sharpness: 0.2),
                                              Beat(t: 0.14, intensity: intensity * 0.6, sharpness: 0.15)])
    }
    /// Two heartbeats that drift into sync, held by a swelling warmth.
    static let mend = VibrationScore(name: "mend", beats: {
        var b: [Beat] = [Beat(t: 0, intensity: 0.5, sharpness: 0.1, duration: 1.6)]
        let a: [Double] = [0.0, 0.55, 1.05, 1.5], c: [Double] = [0.28, 0.72, 1.12, 1.5]
        for x in a { b.append(Beat(t: x, intensity: 0.8, sharpness: 0.25)) }
        for x in c where !a.contains(x) { b.append(Beat(t: x, intensity: 0.55, sharpness: 0.2)) }
        return b
    }())
    /// Friction: crisp, uneven sparks over a short hum.
    static let spark = VibrationScore(name: "spark", beats: [
        Beat(t: 0, intensity: 0.35, sharpness: 0.6, duration: 0.5),
        Beat(t: 0.05, intensity: 0.9, sharpness: 0.9), Beat(t: 0.21, intensity: 0.5, sharpness: 0.8),
        Beat(t: 0.33, intensity: 0.8, sharpness: 1.0), Beat(t: 0.62, intensity: 0.6, sharpness: 0.7),
        Beat(t: 0.70, intensity: 0.9, sharpness: 0.9),
    ])
    /// Repulsion: hard, broken, then nothing.
    static let clash = VibrationScore(name: "clash", beats: [
        Beat(t: 0, intensity: 1, sharpness: 1), Beat(t: 0.06, intensity: 0.9, sharpness: 1),
        Beat(t: 0.12, intensity: 1, sharpness: 0.9), Beat(t: 0.09, intensity: 0.6, sharpness: 1, duration: 0.18),
        Beat(t: 0.42, intensity: 0.5, sharpness: 1),
    ])
    /// A thing sliding home into its slot.
    static let snap = VibrationScore(name: "snap", beats: [Beat(t: 0, intensity: 0.9, sharpness: 0.7),
                                                          Beat(t: 0.05, intensity: 0.4, sharpness: 0.3)])
    /// An interest rising into a value.
    static let ascend = VibrationScore(name: "ascend", beats:
        (0..<8).map { i in Beat(t: Double(i) * 0.07, intensity: 0.25 + Float(i) * 0.09, sharpness: 0.2 + Float(i) * 0.08) }
        + [Beat(t: 0.62, intensity: 1, sharpness: 0.5)])
    /// A tiny detent tick for sliders.
    static let tick = VibrationScore(name: "tick", beats: [Beat(t: 0, intensity: 0.35, sharpness: 0.5)])

    static func meeting(_ m: Meeting) -> VibrationScore {
        switch m { case .mend: return .mend; case .spark: return .spark; case .clash: return .clash }
    }
}

/// Anything that can make a person *feel* resonance: the phone today, a pebble tomorrow.
protocol ResonanceOutput: AnyObject {
    var label: String { get }
    var isAvailable: Bool { get }
    func perform(_ score: VibrationScore)
}

/// iPhone Taptic Engine renderer.
final class PhoneHaptics: ResonanceOutput {
    let label = "iPhone Taptic Engine"
    private var engine: CHHapticEngine?
    var isAvailable: Bool { CHHapticEngine.capabilitiesForHardware().supportsHaptics }

    init() { start() }

    private func start() {
        guard isAvailable else { return }
        do {
            let e = try CHHapticEngine()
            e.playsHapticsOnly = true
            e.isAutoShutdownEnabled = true
            e.resetHandler = { [weak self] in try? self?.engine?.start() }
            try e.start()
            engine = e
        } catch { engine = nil }
    }

    func perform(_ score: VibrationScore) {
        guard let engine else { return }
        let events: [CHHapticEvent] = score.beats.map { b in
            let p = [CHHapticEventParameter(parameterID: .hapticIntensity, value: b.intensity),
                     CHHapticEventParameter(parameterID: .hapticSharpness, value: b.sharpness)]
            return b.duration > 0
                ? CHHapticEvent(eventType: .hapticContinuous, parameters: p, relativeTime: b.t, duration: b.duration)
                : CHHapticEvent(eventType: .hapticTransient, parameters: p, relativeTime: b.t)
        }
        do {
            try engine.start()
            let player = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch { }
    }
}

/// Fans every cue out to all connected outputs.
final class Resonator {
    static let shared = Resonator()
    private(set) var outputs: [ResonanceOutput] = [PhoneHaptics()]
    private var lastTick = Date.distantPast

    func attach(_ o: ResonanceOutput) { outputs.append(o) }
    func play(_ s: VibrationScore) { outputs.forEach { $0.perform(s) } }
    /// Rate-limited detent tick for sliders.
    func tick() {
        let now = Date()
        guard now.timeIntervalSince(lastTick) > 0.035 else { return }
        lastTick = now
        play(.tick)
    }
}
