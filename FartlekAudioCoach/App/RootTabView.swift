import SwiftUI

struct RootTabView: View {
    @ObservedObject var environment: AppEnvironment

    var body: some View {
        TabView {
            SessionsHomeView(sessionStore: environment.sessionStore)
                .tabItem {
                    Label("Sessions", systemImage: "list.bullet.rectangle")
                }

            RunnerHomeView(sessionEngine: environment.sessionEngine)
                .tabItem {
                    Label("Run", systemImage: "figure.run")
                }

            SettingsHomeView(settingsStore: environment.settingsStore)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
