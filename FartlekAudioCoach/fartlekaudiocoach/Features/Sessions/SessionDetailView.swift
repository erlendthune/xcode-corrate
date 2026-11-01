import StoreKit
import SwiftUI

struct SessionDetailView: View {
    @State private var session: SessionTemplate
    var onSelect: ((SessionTemplate) -> Void)?
    @ObservedObject var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var environment: AppEnvironment
    @State private var isShowingPremium = false
    @State private var isShowingPurchaseError = false

    @State private var maxHeartRate = AppSettings.default.maxHeartRate
    @State private var saveError: String?
    @State private var isSaving = false

    init(session: SessionTemplate, purchaseManager: PurchaseManager,
         onSelect: ((SessionTemplate) -> Void)? = nil) {
        _session = State(initialValue: session)
        self.purchaseManager = purchaseManager
        self.onSelect = onSelect
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.name)
                            .font(.title2.weight(.bold))
                        if !session.notes.isEmpty {
                            Text(session.notes)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if session.isPremium {
                        Label("Premium", systemImage: "lock.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Session structure")
                        .font(.headline)

                    Text("Warm up, then speed up to the upper target and slow down to the lower target for each iteration. Targets are percentages of your maximum heart rate.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Stepper("Warmup: \(session.warmupMinutes) minutes", value: $session.warmupMinutes, in: 0...60)

                    ForEach(session.blocks.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Block \(index + 1)")
                                .font(.subheadline.weight(.semibold))
                            Stepper("Iterations: \(session.blocks[index].repetitions)", value: $session.blocks[index].repetitions, in: 1...100)
                            Stepper("Lower target: \(session.blocks[index].lowerTargetPercent)%", value: $session.blocks[index].lowerTargetPercent, in: 1...(session.blocks[index].upperTargetPercent - 1))
                            Stepper("Upper target: \(session.blocks[index].upperTargetPercent)%", value: $session.blocks[index].upperTargetPercent, in: (session.blocks[index].lowerTargetPercent + 1)...100)
                            Text("\(HeartRateConverter.bpm(from: session.blocks[index].lowerTargetPercent, maxHeartRate: maxHeartRate))-\(HeartRateConverter.bpm(from: session.blocks[index].upperTargetPercent, maxHeartRate: maxHeartRate)) BPM at max HR \(maxHeartRate)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        if index < session.blocks.count - 1 {
                            Divider()
                        }
                    }
                }
                .disabled(session.isPremium && !purchaseManager.isPremium)

                Button {
                    if session.isPremium {
                        if purchaseManager.isPremium {
                            startSession()
                        } else {
                            isShowingPremium = true
                        }
                    } else {
                        startSession()
                    }
                } label: {
                    Label(buttonTitle, systemImage: buttonIcon)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)
            }
            .padding()
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { startSession() }
                    .disabled(isSaving || (session.isPremium && !purchaseManager.isPremium))
            }
        }
        .task {
            maxHeartRate = await environment.settingsStore.loadSettings().maxHeartRate
        }
        .alert("Could not save session", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "Please try again.")
        }
        .alert("Premium session", isPresented: $isShowingPremium) {
            Button("Not now", role: .cancel) {}
            Button(purchaseTitle) {
                Task {
                    await purchaseManager.purchase()
                    isShowingPurchaseError = purchaseManager.errorMessage != nil
                }
            }
            Button("Restore purchase") {
                Task {
                    await purchaseManager.restore()
                    isShowingPurchaseError = purchaseManager.errorMessage != nil
                }
            }
        } message: {
            Text("Unlock custom sessions and advanced multi-block workouts with a one-time purchase.\(priceText)")
        }
        .alert("Purchase", isPresented: $isShowingPurchaseError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchaseManager.errorMessage ?? "The purchase could not be completed.")
        }
    }

    private func startSession() {
        guard !isSaving else { return }
        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }
            do {
                var sessions = try await environment.sessionStore.loadSessions()
                if let index = sessions.firstIndex(where: {
                    $0.id == session.id || ($0.isBuiltin && session.isBuiltin && $0.name == session.name)
                }) {
                    sessions[index] = session
                } else {
                    sessions.append(session)
                }
                try await environment.sessionStore.saveSessions(sessions)
                environment.selectedSession = session
                onSelect?(session)
                dismiss()
            } catch {
                saveError = error.localizedDescription
            }
        }
    }

    private var purchaseTitle: String {
        guard let product = purchaseManager.product else { return "Unlock" }
        return "Unlock for \(product.displayPrice)"
    }

    private var priceText: String {
        guard let product = purchaseManager.product else { return "" }
        return " Price: \(product.displayPrice)."
    }

    private var buttonTitle: String {
        session.isPremium && !purchaseManager.isPremium ? purchaseTitle : "Save and Select Session"
    }

    private var buttonIcon: String {
        session.isPremium && !purchaseManager.isPremium ? "lock.fill" : "checkmark"
    }
}
