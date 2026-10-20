import SwiftUI

private enum PhoneStyle {
    static let navy = Color(red: 0.035, green: 0.047, blue: 0.075)
    static let mint = Color(red: 0.45, green: 1, blue: 0.79)
    static let text = Color.white
    static let secondary = Color.white.opacity(0.78)
    static let surface = Color.white.opacity(0.1)
    static let warning = Color.orange
    static let tight: CGFloat = 8
    static let gap: CGFloat = 16
    static let inset: CGFloat = 20
    static let radius: CGFloat = 20
    static let controlHeight: CGFloat = 64
    static let padWidth: CGFloat = 72
}

struct ContentView: View {
    @EnvironmentObject private var session: AirStrumSession
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ViewThatFits(in: .vertical) {
            instrument
            ScrollView {
                instrument
            }
        }
        .background(PhoneStyle.navy.ignoresSafeArea())
        .foregroundStyle(PhoneStyle.text)
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) {
            if scenePhase != .active { release() }
        }
        .onDisappear { release() }
    }

    private var instrument: some View {
        VStack(alignment: .leading, spacing: PhoneStyle.gap) {
            VStack(alignment: .leading, spacing: PhoneStyle.tight) {
                Text(verbatim: "AIRSTRUM")
                    .font(.headline)
                    .foregroundStyle(PhoneStyle.mint)
                Text("Play the air.")
                    .font(.largeTitle.bold())
                Text("Hold a chord with your left hand. Strum with your Apple Watch.")
                    .foregroundStyle(PhoneStyle.secondary)
                status
            }
            chordControls
            Text("Keep both apps open and active while playing.")
                .font(.footnote)
                .foregroundStyle(PhoneStyle.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PhoneStyle.inset)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: PhoneStyle.tight) {
            Label(LocalizedStringKey(session.watchConnected ? "Watch reachable" : "Watch not reachable"),
                  systemImage: session.watchConnected ? "applewatch" : "applewatch.slash")
                .font(.headline)
            if !session.watchConnected {
                Text("Open AirStrum on your paired Apple Watch.")
            }
            Label(LocalizedStringKey(session.isAudioReady ? "Audio ready" : "Audio unavailable"),
                  systemImage: session.isAudioReady ? "speaker.wave.2" : "speaker.slash")
            if !session.isAudioReady {
                Text("Close and reopen AirStrum to try audio again.")
                    .foregroundStyle(PhoneStyle.warning)
            }
            if let error = session.communicationError {
                Text("Watch communication problem. Keep both apps open and check the connection.")
                    .foregroundStyle(PhoneStyle.warning)
                Text(verbatim: error)
                    .font(.footnote)
            }
            if let strum = session.lastStrum {
                Text(LocalizedStringKey(strum.direction == .down ? "Last received: down strum" : "Last received: up strum"))
                    .foregroundStyle(PhoneStyle.secondary)
            } else {
                Text("Waiting for your first strum")
                    .foregroundStyle(PhoneStyle.secondary)
            }
        }
        .font(.subheadline)
        .fixedSize(horizontal: false, vertical: true)
        .padding(PhoneStyle.gap)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PhoneStyle.surface, in: RoundedRectangle(cornerRadius: PhoneStyle.radius))
    }

    private var chordControls: some View {
        VStack(spacing: PhoneStyle.tight) {
            Text(LocalizedStringKey(session.heldChord == nil ? "Hold to play" : "Holding · lift to release"))
                .font(.headline)
                .foregroundStyle(PhoneStyle.secondary)
            LazyVGrid(columns: [GridItem(
                dynamicTypeSize.isAccessibilitySize ? .flexible() : .adaptive(minimum: PhoneStyle.padWidth),
                spacing: PhoneStyle.tight
            )], spacing: PhoneStyle.tight) {
                ForEach(Chord.allCases) { chord in
                    ChordPad(
                        chord: chord,
                        name: chordName(chord),
                        isHeld: session.heldChord == chord,
                        isEnabled: session.isAudioReady,
                        press: { press(chord) },
                        release: {
                            if session.heldChord == chord { release() }
                        }
                    )
                }
            }
            Button("Release chord", action: release)
                .font(.headline)
                .buttonStyle(.bordered)
                .tint(PhoneStyle.mint)
                .disabled(session.heldChord == nil)
        }
    }

    private func press(_ chord: Chord) {
        guard scenePhase == .active, session.isAudioReady, session.heldChord != chord else { return }
        session.press(chord: chord)
    }

    private func release() {
        guard session.heldChord != nil else { return }
        session.releaseChord()
    }

    private func chordName(_ chord: Chord) -> LocalizedStringKey {
        switch chord {
        case .em: "E minor"
        case .g7: "G dominant 7"
        case .c: "C major"
        case .d: "D major"
        case .am: "A minor"
        case .a: "A major"
        case .e: "E major"
        case .dm: "D minor"
        }
    }
}

private struct ChordPad: View {
    let chord: Chord
    let name: LocalizedStringKey
    let isHeld: Bool
    let isEnabled: Bool
    let press: () -> Void
    let release: () -> Void

    @GestureState private var touching = false
    @ScaledMetric(relativeTo: .title2) private var padHeight = PhoneStyle.controlHeight

    var body: some View {
        Text(verbatim: chord.rawValue)
            .font(.title2.bold())
            .frame(maxWidth: .infinity, minHeight: padHeight)
            .foregroundStyle(isHeld ? PhoneStyle.navy : (isEnabled ? PhoneStyle.mint : PhoneStyle.secondary))
            .background(isHeld ? PhoneStyle.mint : PhoneStyle.surface,
                        in: RoundedRectangle(cornerRadius: PhoneStyle.radius))
            .overlay {
                GeometryReader { geometry in
                    Color.clear
                        .contentShape(RoundedRectangle(cornerRadius: PhoneStyle.radius))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .updating($touching) { value, touching, _ in
                                    touching = CGRect(origin: .zero, size: geometry.size).contains(value.location)
                                }
                                .onEnded { _ in release() }
                        )
                }
            }
            .onChange(of: touching) { _, touching in
                if touching && isEnabled { press() } else { release() }
            }
            .onDisappear { release() }
            .accessibilityRepresentation {
                Button {
                    isHeld ? release() : press()
                } label: {
                    Text(name)
                }
                .accessibilityValue(isHeld ? Text("Holding") : Text("Released"))
                .accessibilityHint("Activate to hold or release. You can also use the Press chord and Release chord actions.")
                .accessibilityAction(named: Text("Press chord")) { press() }
                .accessibilityAction(named: Text("Release chord")) { release() }
                .disabled(!isEnabled)
            }
    }
}
