import SwiftUI

struct WatchContentView: View {
    @StateObject private var motion = WatchMotionController()

    var body: some View {
        VStack(spacing: 12) {
            Text("AIRSTRUM")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(Color(red: 0.45, green: 1, blue: 0.79))
            Text(motion.currentChord ?? "—")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text(motion.lastDirection.map { $0 == .down ? "DOWN" : "UP" } ?? "READY")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.6))
            Button(motion.isRunning ? "STOP" : "STRUM") {
                motion.toggle()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.45, green: 1, blue: 0.79))
        }
        .padding()
        .preferredColorScheme(.dark)
    }
}
