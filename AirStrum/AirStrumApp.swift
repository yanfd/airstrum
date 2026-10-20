import SwiftUI

@main
struct AirStrumApp: App {
    @StateObject private var session = AirStrumSession()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
        }
    }
}
