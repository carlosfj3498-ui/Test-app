import SwiftUI
import UnlockCore

@main
struct DesbloqueosApp: App {
    @StateObject private var tracker = UnlockTracker()

    init() {
        PreferenceDefaults.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(tracker)
        }
    }
}
