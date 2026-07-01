import CoreHaptics
import UIKit

/// Core Haptics wrapper. Sharp transient for clean cuts (intensity scales with combo),
/// heavy thud for nicks. Falls back to UIImpactFeedbackGenerator if Core Haptics is
/// unavailable (e.g. simulator).
final class Haptics {
    static let shared = Haptics()

    private var engine: CHHapticEngine?
    private var supportsHaptics = false
    private let fallbackLight = UIImpactFeedbackGenerator(style: .light)
    private let fallbackHeavy = UIImpactFeedbackGenerator(style: .heavy)

    private init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        prepareEngine()
        fallbackLight.prepare()
        fallbackHeavy.prepare()
    }

    private func prepareEngine() {
        guard supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            engine?.stoppedHandler = { _ in }
            try engine?.start()
        } catch {
            supportsHaptics = false
            engine = nil
        }
    }

    /// Clean splice: sharp transient. intensity 0.6..1.0 scaling with combo.
    func splice(combo: Int) {
        let intensity = Float(min(1.0, 0.6 + Double(combo) * 0.04))
        let sharpness: Float = 0.9
        playTransient(intensity: intensity, sharpness: sharpness)
        if !supportsHaptics { fallbackLight.impactOccurred(intensity: CGFloat(intensity)) }
    }

    /// Nick: heavy thud.
    func nick() {
        playTransient(intensity: 1.0, sharpness: 0.2)
        if !supportsHaptics { fallbackHeavy.impactOccurred() }
    }

    func newBest() {
        // A double tap sting.
        playTransient(intensity: 1.0, sharpness: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.playTransient(intensity: 1.0, sharpness: 0.8)
        }
        if !supportsHaptics { fallbackHeavy.impactOccurred() }
    }

    private func playTransient(intensity: Float, sharpness: Float) {
        guard supportsHaptics, let engine = engine else { return }
        let i = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let s = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [i, s], relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            // ignore
        }
    }
}
