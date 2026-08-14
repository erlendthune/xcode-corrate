import SwiftUI

@main
struct FartlekAudioCoachApp: App {
    @StateObject private var environment = AppEnvironment.bootstrap()

    var body: some Scene {
        WindowGroup {
            RootTabView(environment: environment)
        }
    }
}
