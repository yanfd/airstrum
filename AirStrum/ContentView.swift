import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var session: AirStrumSession
    @State private var selectedChord: Chord?

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.047, blue: 0.075).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    liveCard
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(Chord.allCases) { chord in
                            chordButton(chord)
                        }
                    }
                    Text("Hold a chord with your left hand. Strum with your Apple Watch.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.56))
                }
                .padding(22)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AIRSTRUM")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .tracking(3)
                .foregroundStyle(Color(red: 0.45, green: 1, blue: 0.79))
            Text("Play the air.")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("左手按和弦，右手扫弦。\nHold the chord. Strum the air.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))
        }
    }

    private var liveCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(session.watchConnected ? Color(red: 0.45, green: 1, blue: 0.79) : .orange)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 3) {
                Text(session.watchConnected ? "WATCH READY" : "CONNECT APPLE WATCH")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(.white)
                Text(session.lastStrum.map { "\($0.direction == .down ? "DOWN" : "UP") · \(Int($0.velocity * 100))%" } ?? "Waiting for your first strum")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
            }
            Spacer()
            Text(session.heldChord?.rawValue ?? "—")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.45, green: 1, blue: 0.79))
        }
        .padding(18)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
    }

    private func chordButton(_ chord: Chord) -> some View {
        Button {
            if selectedChord == chord { selectedChord = nil; session.releaseChord() }
            else { selectedChord = chord; session.press(chord: chord) }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(chord.rawValue)
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                Text(chord.subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .opacity(0.58)
                Spacer()
                Text(selectedChord == chord ? "HOLDING" : "TOUCH")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.2)
            }
            .foregroundStyle(selectedChord == chord ? Color(red: 0.035, green: 0.047, blue: 0.075) : .white)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            .padding(18)
            .background(selectedChord == chord ? Color(red: 0.45, green: 1, blue: 0.79) : .white.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}
