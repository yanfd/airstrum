import AVFoundation
import Foundation

final class ChordAudioEngine {
    private let engine = AVAudioEngine()
    private let players = (0..<16).map { _ in AVAudioPlayerNode() }
    private let voiceMixer = AVAudioMixerNode()
    private let outputMixer = AVAudioMixerNode()
    private let reverb = AVAudioUnitReverb()
    private let delay = AVAudioUnitDelay()
    private var buffers: [Chord: AVAudioPCMBuffer] = [:]
    private var currentChord: Chord?
    private var releaseDeadline: DispatchTime?
    private var releaseGeneration = 0
    private var outputGain: AUParameter?
    private(set) var isReady = false

    func prepare() {
        do {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            #endif
            engine.attach(voiceMixer)
            engine.attach(outputMixer)
            engine.attach(reverb)
            engine.attach(delay)
            let format = engine.mainMixerNode.outputFormat(forBus: 0)
            for (index, player) in players.enumerated() {
                engine.attach(player)
                engine.connect(player, to: voiceMixer, fromBus: 0, toBus: AVAudioNodeBus(index), format: format)
            }
            engine.connect(voiceMixer, to: reverb, format: format)
            voiceMixer.outputVolume = 0.5
            engine.connect(reverb, to: delay, format: format)
            engine.connect(delay, to: outputMixer, format: format)
            engine.connect(outputMixer, to: engine.mainMixerNode, format: format)
            outputGain = outputMixer.auAudioUnit.parameterTree?.parameter(
                withID: kMultiChannelMixerParam_Volume, scope: kAudioUnitScope_Output, element: 0
            )
            reverb.loadFactoryPreset(.mediumHall)
            reverb.wetDryMix = 18
            delay.wetDryMix = 8
            for chord in Chord.allCases {
                guard buffer(for: chord) != nil else { return }
            }
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
        releaseGeneration += 1
        guard isReady, releaseDeadline == nil else { return }
        let deadline = DispatchTime.now() + .milliseconds(20)
        releaseDeadline = deadline
        if let outputGain {
            let frames = AUAudioFrameCount(outputMixer.outputFormat(forBus: 0).sampleRate * 0.01)
            outputMixer.auAudioUnit.scheduleParameterBlock(AUEventSampleTimeImmediate, frames, outputGain.address, 0)
        } else {
            outputMixer.outputVolume = 0
        }
        DispatchQueue.main.asyncAfter(deadline: deadline) { [weak self] in
            guard let self else { return }
            self.outputMixer.outputVolume = 0
            for player in self.players { player.stop() }
            self.reverb.reset()
            self.delay.reset()
            self.releaseDeadline = nil
        }
    }

    func strum(velocity: Double, direction: StrumDirection) {
        guard isReady, let currentChord, let buffer = buffers[currentChord] else { return }
        if let releaseDeadline {
            let generation = releaseGeneration
            DispatchQueue.main.asyncAfter(deadline: releaseDeadline) { [weak self] in
                guard let self, self.releaseGeneration == generation,
                      self.currentChord == currentChord else { return }
                self.strum(velocity: velocity, direction: direction)
            }
            return
        }
        guard let player = players.first(where: { player in
            guard player.isPlaying else { return true }
            guard let renderTime = player.lastRenderTime,
                  renderTime.isSampleTimeValid || renderTime.isHostTimeValid,
                  let playerTime = player.playerTime(forNodeTime: renderTime) else { return false }
            return playerTime.sampleTime >= AVAudioFramePosition(buffer.frameLength)
        }) else { return }
        player.stop()
        let accent = Float(min(max(velocity, 0.15), 1.0))
        player.volume = accent
        outputMixer.outputVolume = 1
        player.scheduleBuffer(buffer, at: nil, options: [])
        player.play()
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
            .g7: [98.00, 123.47, 146.83, 196.00, 174.61],
            .c: [65.41, 130.81, 164.81, 196.00, 261.63],
            .d: [73.42, 110.00, 146.83, 185.00, 293.66],
            .am: [110.00, 164.81, 220.00, 261.63, 329.63],
            .a: [110.00, 164.81, 220.00, 277.18, 329.63],
            .e: [82.41, 123.47, 164.81, 207.65, 246.94],
            .dm: [73.42, 110.00, 146.83, 174.61, 293.66]
        ]
        let frequencies = ratios[chord, default: ratios[.em]!]
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let attack = min(t / 0.025, 1)
            let release = min(max((1.6 - t) / 0.35, 0), 1)
            let envelope = attack * exp(-3.5 * t) * release
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
