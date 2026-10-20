import AVFoundation
import Foundation

final class ChordAudioEngine {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let reverb = AVAudioUnitReverb()
    private let delay = AVAudioUnitDelay()
    private var buffers: [Chord: AVAudioPCMBuffer] = [:]
    private var currentChord: Chord?
    private(set) var isReady = false

    func prepare() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            engine.attach(player)
            engine.attach(reverb)
            engine.attach(delay)
            let format = engine.mainMixerNode.outputFormat(forBus: 0)
            engine.connect(player, to: reverb, format: format)
            engine.connect(reverb, to: delay, format: format)
            engine.connect(delay, to: engine.mainMixerNode, format: format)
            reverb.loadFactoryPreset(.mediumHall)
            reverb.wetDryMix = 18
            delay.wetDryMix = 8
            try engine.start()
            isReady = true
        } catch {
            isReady = false
        }
    }

    func beginChord(_ chord: Chord) {
        currentChord = chord
    }

    func releaseChord() {
        currentChord = nil
    }

    func strum(velocity: Double, direction: StrumDirection) {
        guard isReady, let currentChord, let buffer = buffer(for: currentChord) else { return }
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: [])
        player.play()
        let accent = Float(min(max(velocity, 0.15), 1.0))
        player.volume = accent
        if direction == .up { delay.feedback = 12 } else { delay.feedback = 7 }
    }

    private func buffer(for chord: Chord) -> AVAudioPCMBuffer? {
        if let cached = buffers[chord] { return cached }
        let sampleRate = engine.mainMixerNode.outputFormat(forBus: 0).sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * 1.6)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: engine.mainMixerNode.outputFormat(forBus: 0), frameCapacity: frameCount),
              let channels = buffer.floatChannelData else { return nil }
        buffer.frameLength = frameCount
        let ratios: [Chord: [Double]] = [
            .em: [82.41, 123.47, 164.81, 196.00, 246.94],
            .g7: [98.00, 123.47, 146.83, 196.00, 246.94],
            .c: [65.41, 130.81, 164.81, 196.00, 246.94],
            .d: [73.42, 110.00, 146.83, 220.00, 293.66],
            .am: [110.00, 164.81, 220.00, 261.63, 329.63],
            .a: [110.00, 164.81, 220.00, 277.18, 329.63],
            .e: [82.41, 123.47, 164.81, 207.65, 246.94],
            .dm: [73.42, 110.00, 146.83, 220.00, 293.66]
        ]
        let frequencies = ratios[chord, default: ratios[.em]!]
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let attack = min(t / 0.025, 1)
            let release = min(max((1.6 - t) / 0.35, 0), 1)
            let envelope = attack * release
            let value = frequencies.enumerated().reduce(0.0) { partial, item in
                partial + sin(2 * .pi * item.element * t) * (0.22 / Double(item.offset + 1))
            } * envelope
            for channel in 0..<Int(buffer.format.channelCount) {
                channels[channel][frame] = Float(value)
            }
        }
        buffers[chord] = buffer
        return buffer
    }
}
