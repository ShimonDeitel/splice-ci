import AVFoundation

/// Procedural SFX with no asset files. Generates short tonal buffers at runtime:
/// a crisp rising-pitch "tck" snip (pitch rises one semitone per combo step), a wet
/// "splrk" for the nick, and a triumphant sting for new-best. Uses AVAudioEngine with a
/// player node so it's low-latency and fully offline.
final class SpliceAudio {
    static let shared = SpliceAudio()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44100
    private var started = false
    private var format: AVAudioFormat!

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func start() {
        guard !started else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            player.play()
            started = true
        } catch {
            started = false
        }
    }

    /// Clean snip. baseFreq rises a semitone per combo step (ratio 2^(1/12)).
    func snip(combo: Int) {
        let semis = min(combo, 24)
        let freq = 880.0 * pow(2.0, Double(semis) / 12.0)
        let buf = makeTone(freq: freq, duration: 0.07, attack: 0.002, decay: 0.06, kind: .snip)
        schedule(buf)
    }

    func nick() {
        let buf = makeTone(freq: 140, duration: 0.22, attack: 0.001, decay: 0.21, kind: .noise)
        schedule(buf)
    }

    func newBest() {
        // A quick rising arpeggio.
        let freqs = [659.25, 783.99, 987.77, 1318.5]
        var t = 0.0
        for f in freqs {
            let buf = makeTone(freq: f, duration: 0.10, attack: 0.003, decay: 0.09, kind: .snip)
            scheduleAfter(buf, delay: t)
            t += 0.06
        }
    }

    private enum ToneKind { case snip, noise }

    private func schedule(_ buffer: AVAudioPCMBuffer?) {
        guard started, let buffer = buffer else { return }
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }

    private func scheduleAfter(_ buffer: AVAudioPCMBuffer?, delay: Double) {
        guard started, let buffer = buffer else { return }
        if delay <= 0 { schedule(buffer); return }
        let sampleTime = AVAudioFramePosition(delay * sampleRate)
        let when = AVAudioTime(sampleTime: (player.lastRenderTime?.sampleTime ?? 0) + sampleTime,
                               atRate: sampleRate)
        player.scheduleBuffer(buffer, at: when, options: [], completionHandler: nil)
    }

    private func makeTone(freq: Double, duration: Double, attack: Double, decay: Double, kind: ToneKind) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(duration * sampleRate)
        guard frames > 0, let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buf.frameLength = frames
        guard let ch = buf.floatChannelData?[0] else { return nil }
        var phase = 0.0
        let inc = 2.0 * Double.pi * freq / sampleRate
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            // ADSR-ish envelope: fast attack, exponential decay.
            var env: Double
            if t < attack { env = t / attack } else { env = exp(-(t - attack) / decay) }
            var sample: Double
            switch kind {
            case .snip:
                // bright tone + a hint of its octave for a "tck" click
                sample = sin(phase) * 0.6 + sin(phase * 2.0) * 0.2
            case .noise:
                sample = (Double.random(in: -1...1) * 0.7) + sin(phase) * 0.3
            }
            ch[i] = Float(sample * env * 0.5)
            phase += inc
        }
        return buf
    }
}
