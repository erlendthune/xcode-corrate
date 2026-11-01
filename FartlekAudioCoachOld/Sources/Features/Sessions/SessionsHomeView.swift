import SwiftUI

struct SessionsHomeView: View {
    let sessionStore: SessionStore
    @State private var sessions: [SessionTemplate] = []

    var body: some View {
        NavigationStack {
            List(sessions) { session in
                VStack(alignment: .leading) {
                    Text(session.name)
                        .font(.headline)
                    Text("\(session.blocks.count) blocks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Sessions")
            .task {
                sessions = (try? sessionStore.loadSessions()) ?? []
            }
        }
    }
}
