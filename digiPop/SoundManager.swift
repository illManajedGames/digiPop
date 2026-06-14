import AVFoundation

class SoundManager {
    static let shared = SoundManager()

    private let engine       = AVAudioEngine()
    private let popInPlayer  = AVAudioPlayerNode()
    private let popOutPlayer = AVAudioPlayerNode()
    private let popInReverb  = AVAudioUnitReverb()
    private let sampleRate: Double = 44100
    private let variantCount = 8

    private var popInBuffers:  [AVAudioPCMBuffer] = []
    private var popOutBuffers: [AVAudioPCMBuffer] = []
    private var popInIdx  = 0
    private var popOutIdx = 0

    private init() {
        engine.attach(popInPlayer)
        engine.attach(popOutPlayer)
        engine.attach(popInReverb)

        popInReverb.loadFactoryPreset(.smallRoom)
        popInReverb.wetDryMix = 15

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }

        engine.connect(popInPlayer,  to: popInReverb,          format: format)
        engine.connect(popInReverb,  to: engine.mainMixerNode, format: format)
        engine.connect(popOutPlayer, to: engine.mainMixerNode, format: format)

        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
        } catch {}

        popInPlayer.play()
        popOutPlayer.play()
        applySettings()
        buildBuffers()
    }

    // MARK: - Public API

    func applySettings() {
        popInPlayer.volume  = SettingsManager.shared.effectivePopInVolume
        popOutPlayer.volume = SettingsManager.shared.effectivePopOutVolume
    }

    func reloadBuffers() {
        buildBuffers()
    }

    func playPopIn() {
        guard !popInBuffers.isEmpty else { return }
        let buf = popInBuffers[popInIdx % popInBuffers.count]
        popInIdx += 1
        popInPlayer.scheduleBuffer(buf, at: nil, options: .interrupts)
    }

    func playPopOut() {
        guard !popOutBuffers.isEmpty else { return }
        let buf = popOutBuffers[popOutIdx % popOutBuffers.count]
        popOutIdx += 1
        popOutPlayer.scheduleBuffer(buf, at: nil, options: .interrupts)
    }

    // MARK: - Buffer building

    private func buildBuffers() {
        let profile = SettingsManager.shared.soundProfile
        let pitchRange: ClosedRange<Double>
        switch profile {
        case .soft:   pitchRange = 0.93...1.07      // wider for snare body variation
        case .droid:  pitchRange = 0.97...1.03     // slight glitch variation
        case .xylo:   pitchRange = 0.92...1.08     // mallet strike variation
        default:      pitchRange = 0.90...1.10
        }
        popInBuffers  = (0..<variantCount).compactMap { _ in makePopInBuffer(pitch:  Double.random(in: pitchRange), profile: profile) }
        popOutBuffers = (0..<variantCount).compactMap { _ in makePopOutBuffer(pitch: Double.random(in: pitchRange), profile: profile) }
        popInIdx  = 0
        popOutIdx = 0
    }

    private func makePopInBuffer(pitch: Double, profile: SoundProfile) -> AVAudioPCMBuffer? {
        switch profile {
        case .classic: return makeClassicPopInBuffer(pitch: pitch)
        case .soft:    return makeSoftPopInBuffer(pitch: pitch)
        case .droid:   return makeDroidPopInBuffer(pitch: pitch)
        case .xylo:    return makeXyloPopInBuffer(pitch: pitch)
        }
    }

    private func makePopOutBuffer(pitch: Double, profile: SoundProfile) -> AVAudioPCMBuffer? {
        switch profile {
        case .classic: return makeClassicPopOutBuffer(pitch: pitch)
        case .soft:    return makeSoftPopOutBuffer(pitch: pitch)
        case .droid:   return makeDroidPopOutBuffer(pitch: pitch)
        case .xylo:    return makeXyloPopOutBuffer(pitch: pitch)
        }
    }

    // MARK: - Classic synthesis

    /// Deep tick — sharp transient + low-mid ring (~380 Hz) with sub-bass body.
    private func makeClassicPopInBuffer(pitch: Double) -> AVAudioPCMBuffer? {
        let duration = 0.045
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        else { return nil }
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        var ringPhase: Double = 0
        var bodyPhase: Double = 0

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let click = Double.random(in: -1.0...1.0) * exp(-800.0 * t) * 0.60
            ringPhase += 2.0 * .pi * (308.0 * pitch) / sampleRate
            let ring   = sin(ringPhase) * exp(-80.0 * t) * 0.50
            bodyPhase += 2.0 * .pi * (73.0 * pitch) / sampleRate
            let body   = sin(bodyPhase) * exp(-40.0 * t) * 0.38
            data[i]    = Float((click + ring + body) * 0.82)
        }
        return buffer
    }

    /// Tock — same shape as tick, lower-frequency ring (~600 Hz).
    private func makeClassicPopOutBuffer(pitch: Double) -> AVAudioPCMBuffer? {
        let duration = 0.030
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        else { return nil }
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        var phase: Double = 0

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let click = Double.random(in: -1.0...1.0) * exp(-800.0 * t) * 0.65
            let freq  = 600.0 * pitch
            phase    += 2.0 * .pi * freq / sampleRate
            let ring  = sin(phase) * exp(-90.0 * t) * 0.50
            data[i]   = Float((click + ring) * 0.85)
        }
        return buffer
    }

    // MARK: - Soft synthesis (marching band drums)

    /// Marching bass drum — deep boom with beater thwack and characteristic pitch drop.
    private func makeSoftPopInBuffer(pitch: Double) -> AVAudioPCMBuffer? {
        let baseFreq      = 55.0 * pitch * Double.random(in: 0.96...1.04)
        let beaterDecay   = Double.random(in: 20.0...32.0)
        let duration      = 0.38
        let frameCount    = AVAudioFrameCount(sampleRate * duration)
        guard let format  = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer  = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        else { return nil }
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        var ph1 = 0.0, ph2 = 0.0

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            // Beater impact transient
            let beater = Double.random(in: -1.0...1.0) * exp(-beaterDecay * t) * 0.40
            // Pitch envelope: membrane stretches on impact, drops to rest frequency over ~25ms
            let pitchEnv = 1.0 + 0.45 * exp(-120.0 * t)
            ph1 += 2.0 * .pi * (baseFreq * pitchEnv) / sampleRate
            ph2 += 2.0 * .pi * (baseFreq * pitchEnv * 1.52) / sampleRate
            let body  = sin(ph1) * exp(-6.5 * t) * 0.68
            let mode2 = sin(ph2) * exp(-16.0 * t) * 0.20
            data[i] = Float((beater + body + mode2) * 0.86)
        }
        return buffer
    }

    // MARK: - Droid synthesis (square wave blips)

    /// Low square-wave blip — C3 (130.81 Hz), punchy digital buzz.
    private func makeDroidPopInBuffer(pitch: Double) -> AVAudioPCMBuffer? {
        let baseFreq = 130.81 * pitch
        let duration = 0.08
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        else { return nil }
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        var ph1 = 0.0, ph3 = 0.0, ph5 = 0.0, ph7 = 0.0

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let env = exp(-32.0 * t)
            ph1 += 2 * .pi * baseFreq        / sampleRate
            ph3 += 2 * .pi * (baseFreq * 3)  / sampleRate
            ph5 += 2 * .pi * (baseFreq * 5)  / sampleRate
            ph7 += 2 * .pi * (baseFreq * 7)  / sampleRate
            // Odd-harmonic Fourier series approximation of a square wave
            let sq = sin(ph1) + (1.0/3.0)*sin(ph3) + (1.0/5.0)*sin(ph5) + (1.0/7.0)*sin(ph7)
            data[i] = Float(sq * env * 0.48)
        }
        return buffer
    }

    /// High square-wave chirp — A4 (440 Hz), crisp digital beep.
    private func makeDroidPopOutBuffer(pitch: Double) -> AVAudioPCMBuffer? {
        let baseFreq = 440.0 * pitch
        let duration = 0.055
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        else { return nil }
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        var ph1 = 0.0, ph3 = 0.0, ph5 = 0.0, ph7 = 0.0

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let env = exp(-55.0 * t)
            ph1 += 2 * .pi * baseFreq        / sampleRate
            ph3 += 2 * .pi * (baseFreq * 3)  / sampleRate
            ph5 += 2 * .pi * (baseFreq * 5)  / sampleRate
            ph7 += 2 * .pi * (baseFreq * 7)  / sampleRate
            let sq = sin(ph1) + (1.0/3.0)*sin(ph3) + (1.0/5.0)*sin(ph5) + (1.0/7.0)*sin(ph7)
            data[i] = Float(sq * env * 0.44)
        }
        return buffer
    }

    // MARK: - Xylo synthesis (bright mallet strikes)

    /// E4 (329.63 Hz) mallet strike — inharmonic partials, fast woody decay.
    private func makeXyloPopInBuffer(pitch: Double) -> AVAudioPCMBuffer? {
        let baseFreq   = 329.63 * pitch
        let duration   = 0.28
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        else { return nil }
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        var ph1 = 0.0, ph2 = 0.0, ph3 = 0.0

        for i in 0..<Int(frameCount) {
            let t     = Double(i) / sampleRate
            // Mallet click transient
            let click = Double.random(in: -1.0...1.0) * exp(-600.0 * t) * 0.18
            // Xylophone inharmonic partials: f1, ~3.0f1, ~6.0f1
            ph1 += 2 * .pi * baseFreq          / sampleRate
            ph2 += 2 * .pi * (baseFreq * 3.01) / sampleRate
            ph3 += 2 * .pi * (baseFreq * 6.04) / sampleRate
            let sample = sin(ph1) * 0.60 * exp(-14.0 * t)
                       + sin(ph2) * 0.28 * exp(-28.0 * t)
                       + sin(ph3) * 0.10 * exp(-55.0 * t)
            data[i] = Float((sample + click) * 0.78)
        }
        return buffer
    }

    /// B4 (493.88 Hz) mallet strike — same model, brighter and shorter.
    private func makeXyloPopOutBuffer(pitch: Double) -> AVAudioPCMBuffer? {
        let baseFreq   = 493.88 * pitch
        let duration   = 0.20
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        else { return nil }
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        var ph1 = 0.0, ph2 = 0.0, ph3 = 0.0

        for i in 0..<Int(frameCount) {
            let t     = Double(i) / sampleRate
            let click = Double.random(in: -1.0...1.0) * exp(-700.0 * t) * 0.16
            ph1 += 2 * .pi * baseFreq          / sampleRate
            ph2 += 2 * .pi * (baseFreq * 3.01) / sampleRate
            ph3 += 2 * .pi * (baseFreq * 6.04) / sampleRate
            let sample = sin(ph1) * 0.58 * exp(-18.0 * t)
                       + sin(ph2) * 0.26 * exp(-35.0 * t)
                       + sin(ph3) * 0.09 * exp(-65.0 * t)
            data[i] = Float((sample + click) * 0.74)
        }
        return buffer
    }

    /// Marching snare — bright sharp crack + tight wire rattle, very short decay.
    private func makeSoftPopOutBuffer(pitch: Double) -> AVAudioPCMBuffer? {
        let duration   = 0.14
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        else { return nil }
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        // Per-hit randomisation
        let bodyFreq   = 245.0 * pitch * Double.random(in: 0.92...1.08)
        let crackDecay = Double.random(in: 38.0...58.0)
        let buzzDecay  = Double.random(in: 20.0...30.0)
        let buzzLevel  = Double.random(in: 0.20...0.32)

        var bodyPhase = 0.0

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            // Very bright noise crack — marching snares hit hard
            let crack = Double.random(in: -1.0...1.0) * exp(-crackDecay * t) * 0.72
            // Tight head resonance (high-tension marching head)
            bodyPhase += 2.0 * .pi * bodyFreq / sampleRate
            let body   = sin(bodyPhase) * exp(-58.0 * t) * 0.24
            // Short snare wire buzz
            let buzz   = Double.random(in: -1.0...1.0) * exp(-buzzDecay * t) * buzzLevel
            data[i]    = Float((crack + body + buzz) * 0.90)
        }
        return buffer
    }
}
