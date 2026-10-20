import AVFoundation
import Foundation

private enum CheckFailure: Error {
    case failed(String)
}

private func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw CheckFailure.failed(message) }
}

private func field<Value>(_ name: String, of owner: Any) throws -> Value {
    guard let value = Mirror(reflecting: owner).children.first(where: { $0.label == name })?.value as? Value else {
        throw CheckFailure.failed("Missing engine field: \(name)")
    }
    return value
}

private func peak(_ samples: [Float]) -> Float {
    samples.reduce(0) { max($0, abs($1)) }
}

private func rms(_ samples: [Float]) -> Double {
    sqrt(samples.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(samples.count))
}

private final class OfflineVoice {
    let audio = ChordAudioEngine()
    let engine: AVAudioEngine
    let players: [AVAudioPlayerNode]
    let output: AVAudioPCMBuffer

    init() throws {
        engine = try field("engine", of: audio)
        players = try field("players", of: audio)
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 512)
        audio.prepare()
        try require(audio.isReady, "Engine preparation failed")
        output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512)!
    }

    deinit { engine.stop() }

    func render(_ seconds: Double) throws -> [Float] {
        var remaining = Int(seconds * engine.manualRenderingFormat.sampleRate)
        var samples: [Float] = []
        while remaining > 0 {
            let frames: AVAudioFrameCount = 512
            let status = try engine.renderOffline(frames, to: output)
            try require(status == .success, "Offline render status: \(status)")
            let channels = output.floatChannelData!
            for channel in 0..<Int(output.format.channelCount) {
                for frame in 0..<Int(frames) {
                    let value = channels[channel][frame]
                    try require(value.isFinite, "Nonfinite audio sample")
                    samples.append(value)
                }
            }
            remaining -= Int(frames)
        }
        return samples
    }

    func awaitRelease() throws {
        let deadline = Date().addingTimeInterval(0.5)
        while players.contains(where: \.isPlaying), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.002))
        }
        try require(players.allSatisfy { !$0.isPlaying }, "Release cleanup did not finish")
    }
}

private func amplitude(_ frequency: Double, in buffer: AVAudioPCMBuffer) -> Double {
    let sampleRate = buffer.format.sampleRate
    let start = Int(0.08 * sampleRate)
    let end = Int(0.68 * sampleRate)
    let samples = buffer.floatChannelData![0]
    var real = 0.0
    var imaginary = 0.0
    var weight = 0.0
    for frame in start..<end {
        let window = 0.5 - 0.5 * cos(2 * .pi * Double(frame - start) / Double(end - start - 1))
        let phase = 2 * .pi * frequency * Double(frame) / sampleRate
        real += Double(samples[frame]) * window * cos(phase)
        imaginary += Double(samples[frame]) * window * sin(phase)
        weight += window
    }
    return 2 * hypot(real, imaginary) / weight
}

@main
private enum AudioVoiceChecks {
    static func main() throws {
        print("macOS offline adaptation: iOS-only AVAudioSession setup is excluded; production engine, synthesis and effects are unchanged.")
        var failures: [String] = []
        func check(_ name: String, _ body: () throws -> Void) {
            do {
                try body()
                print("PASS \(name)")
            } catch {
                failures.append(name)
                print("FAIL \(name): \(error)")
            }
        }

        check("all chord buffers are prewarmed") {
            let voice = try OfflineVoice()
            let buffers: [Chord: AVAudioPCMBuffer] = try field("buffers", of: voice.audio)
            try require(buffers.count == Chord.allCases.count, "Preparation must synthesize every chord")
        }
        check("no-held strum is silent") {
            let voice = try OfflineVoice()
            voice.audio.strum(velocity: 1, direction: .down)
            let samples = try voice.render(0.1)
            try require(peak(samples) == 0, "Unheld strum produced sound")
        }
        check("rapid strum preserves the previous voice") {
            let voice = try OfflineVoice()
            voice.audio.beginChord(.em)
            voice.audio.strum(velocity: 1, direction: .down)
            _ = try voice.render(0.1)
            let before = voice.players[0].playerTime(forNodeTime: voice.players[0].lastRenderTime!)!.sampleTime
            voice.audio.strum(velocity: 0.7, direction: .up)
            let samples = try voice.render(0.1)
            let after = voice.players[0].playerTime(forNodeTime: voice.players[0].lastRenderTime!)!.sampleTime
            try require(after > before && voice.players[1].isPlaying, "Earlier voice was restarted or overlap missing")
            try require(rms(samples) > 0.005, "Overlapping voices are inaudible")
        }
        check("held strum decays naturally") {
            let voice = try OfflineVoice()
            voice.audio.beginChord(.em)
            voice.audio.strum(velocity: 1, direction: .down)
            let early = try voice.render(0.15)
            _ = try voice.render(0.7)
            let late = try voice.render(0.15)
            try require(rms(late) < rms(early) * 0.25, "Held chord sustains instead of decaying")
        }
        check("release ramps down and leaves no effect tail") {
            let voice = try OfflineVoice()
            voice.audio.beginChord(.g7)
            voice.audio.strum(velocity: 1, direction: .up)
            _ = try voice.render(0.2)
            voice.audio.releaseChord()
            let ramp = try voice.render(0.006)
            try require(peak(ramp) > 0.0001, "Release hard-cut instead of ramping")
            _ = try voice.render(0.02)
            try voice.awaitRelease()
            let tail = try voice.render(0.3)
            try require(peak(tail) < 0.0001, "Release is not quiet after cleanup: \(peak(tail))")
            let settled = try voice.render(0.1)
            try require(peak(settled) < 0.000001, "Effect tail persists after release cleanup")
            voice.audio.strum(velocity: 1, direction: .down)
            let unheld = try voice.render(0.1)
            try require(peak(unheld) < 0.000001, "Release did not restore chord gating")
        }
        check("fresh chord after release matches a clean engine") {
            let reused = try OfflineVoice()
            reused.audio.beginChord(.em)
            reused.audio.strum(velocity: 1, direction: .down)
            _ = try reused.render(0.2)
            reused.audio.releaseChord()
            _ = try reused.render(0.03)
            try reused.awaitRelease()
            let clean = try OfflineVoice()
            for voice in [reused, clean] {
                voice.audio.beginChord(.d)
                voice.audio.strum(velocity: 1, direction: .down)
            }
            let fresh = try reused.render(0.2)
            let reference = try clean.render(0.2)
            try require(rms(fresh) > 0.005, "Fresh chord is muted")
            try require(abs(rms(fresh) - rms(reference)) < rms(reference) * 0.25,
                        "Fresh chord energy differs materially from a clean engine")
        }

        let expected: [Chord: [Double]] = [
            .em: [82.41, 123.47, 164.81, 196, 246.94],
            .g7: [98, 123.47, 146.83, 196, 174.61],
            .c: [65.41, 130.81, 164.81, 196, 261.63],
            .d: [73.42, 110, 146.83, 185, 293.66],
            .am: [110, 164.81, 220, 261.63, 329.63],
            .a: [110, 164.81, 220, 277.18, 329.63],
            .e: [82.41, 123.47, 164.81, 207.65, 246.94],
            .dm: [73.42, 110, 146.83, 174.61, 293.66]
        ]
        let excluded: [Chord: [Double]] = [.c: [246.94], .d: [174.61], .dm: [185]]
        for chord in Chord.allCases {
            check("\(chord.rawValue) rendered harmony frequencies") {
                let voice = try OfflineVoice()
                voice.audio.beginChord(chord)
                voice.audio.strum(velocity: 1, direction: .down)
                let buffers: [Chord: AVAudioPCMBuffer] = try field("buffers", of: voice.audio)
                let buffer = buffers[chord]!
                for frequency in expected[chord]! {
                    try require(amplitude(frequency, in: buffer) > 0.005, "Missing \(frequency) Hz")
                }
                for frequency in excluded[chord, default: []] {
                    try require(amplitude(frequency, in: buffer) < 0.002, "Unintended \(frequency) Hz")
                }
            }
        }
        for rate in [8, 12] {
            for chord in Chord.allCases {
                check("\(chord.rawValue) bounded output at \(rate) strums/second") {
                    let voice = try OfflineVoice()
                    voice.audio.beginChord(chord)
                    var maximum: Float = 0
                    for index in 0..<(rate * 3) {
                        voice.audio.strum(velocity: 1, direction: index.isMultiple(of: 2) ? .down : .up)
                        maximum = max(maximum, peak(try voice.render(1 / Double(rate))))
                    }
                    maximum = max(maximum, peak(try voice.render(2)))
                    print("  peak=\(maximum)")
                    try require(maximum > 0.01 && maximum < 0.98, "Clipped or inaudible fast strums: \(maximum)")
                }
            }
        }
        fflush(stdout)
        if !failures.isEmpty { exit(1) }
    }
}
