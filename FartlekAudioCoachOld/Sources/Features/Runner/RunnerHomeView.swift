import SwiftUI

struct RunnerHomeView: View {
    let sessionEngine: SessionEngine

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Runner")
                    .font(.title2)
                    .bold()
                Text("Session execution UI will be implemented in the next milestone.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Run")
        }
    }
}
