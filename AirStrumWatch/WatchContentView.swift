import SwiftUI

private enum WatchStyle {
    static let navy = Color(red: 0.035, green: 0.047, blue: 0.075)
    static let mint = Color(red: 0.45, green: 1, blue: 0.79)
    static let text = Color.white
    static let secondary = Color.white.opacity(0.78)
    static let warning = Color.orange
    static let gap: CGFloat = 12
}

struct WatchContentView: View {
    @StateObject private var motion = WatchMotionController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WatchStyle.gap) {
                Text(verbatim: "AIRSTRUM")
                    .font(.headline)
                    .foregroundStyle(WatchStyle.mint)
                Button(LocalizedStringKey(motion.isRunning ? "Stop detecting" : "Start detecting")) {
                    motion.toggle()
                }
                .buttonStyle(.borderedProminent)
                .tint(WatchStyle.mint)
                .foregroundStyle(WatchStyle.navy)
                Text(LocalizedStringKey(motion.isRunning ? "Motion detection active" : "Motion detection stopped"))
                    .font(.headline)
                if let chord = motion.currentChord {
                    Text("Last chord received: \(chord)")
                } else {
                    Text("No chord received. Hold a chord on iPhone.")
                }
                if let direction = motion.lastDirection {
                    Text(LocalizedStringKey(direction == .down ? "Last detected: down strum" : "Last detected: up strum"))
                } else if motion.isRunning {
                    Text("Waiting for a wrist strum")
                }
                Text("Detection does not confirm playback on iPhone.")
                    .foregroundStyle(WatchStyle.secondary)
                if let error = motion.motionError {
                    Text("Motion unavailable. Stop and start detection to try again.")
                        .foregroundStyle(WatchStyle.warning)
                    Text(verbatim: error).font(.footnote)
                }
                if let error = motion.communicationError {
                    Text("iPhone communication problem. Open AirStrum on your paired iPhone and check the connection.")
                        .foregroundStyle(WatchStyle.warning)
                    Text(verbatim: error).font(.footnote)
                }
                Text("Keep this app active and AirStrum open on iPhone. Detection stops when this app becomes inactive.")
                    .foregroundStyle(WatchStyle.secondary)
            }
            .font(.body)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(WatchStyle.gap)
        }
        .background(WatchStyle.navy.ignoresSafeArea())
        .foregroundStyle(WatchStyle.text)
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) {
            if scenePhase != .active { stopDetection() }
        }
        .onDisappear { stopDetection() }
    }

    private func stopDetection() {
        if motion.isRunning { motion.toggle() }
    }
}
