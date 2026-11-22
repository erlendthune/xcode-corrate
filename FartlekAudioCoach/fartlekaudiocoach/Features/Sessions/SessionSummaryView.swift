import SwiftUI

struct SessionSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    let session: SessionTemplate

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(session.name)
                        .font(.headline)
                        .accessibilityIdentifier("sessionSummaryName")
                    LabeledContent("Warmup", value: session.warmupSummary)
                    Text("Read-only workout summary")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !session.notes.isEmpty {
                    Section("Notes") {
                        Text(session.notes)
                    }
                }

                Section("Blocks") {
                    ForEach(Array(session.blocks.enumerated()), id: \.element.id) { index, block in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Block \(index + 1)")
                                .font(.headline)
                            Text("\(block.repetitions) repetitions")
                            Text("\(block.lowerTargetPercent)–\(block.upperTargetPercent)% of maximum heart rate")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Session Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("dismissSessionSummary")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}