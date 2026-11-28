import SwiftUI

struct SessionsHomeView: View {
    let sessionStore: SessionStore
    @ObservedObject var purchaseManager: PurchaseManager
    @State private var sessions: [SessionTemplate] = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(sessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session, purchaseManager: purchaseManager)
                        } label: {
                            SessionRow(session: session)
                        }
                    }
                } header: {
                    Text("Ready to run")
                } footer: {
                    Text("All workouts are available. Choose a session to edit and save it.")
                }
                .task {
                    sessions = (try? await sessionStore.loadSessions()) ?? []
                }
            }
            .navigationTitle("Sessions")
        }
    }
}

private struct SessionRow: View {
    let session: SessionTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.name)
                    .font(.headline)
                Spacer()
            }

            if !session.notes.isEmpty {
                Text(session.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if session.warmupMinutes > 0 {
                Text("Warmup: \(session.warmupMinutes) minutes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(session.blocks.enumerated()), id: \.element.id) { index, block in
                HStack(spacing: 6) {
                    Text("Block \(index + 1)")
                    Text("\(block.repetitions) x \(block.lowerTargetPercent)-\(block.upperTargetPercent)%")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}
