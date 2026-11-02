import StoreKit
import SwiftUI

enum AppMenuDestination: String, Identifiable {
    case purchase, help, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .purchase: return "Buy app"
        case .help: return "Help"
        case .about: return "About"
        }
    }
}

struct AppMenuView: View {
    let destination: AppMenuDestination
    @ObservedObject var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var restoreMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                switch destination {
                case .purchase:
                    purchaseContent
                case .help:
                    helpContent
                case .about:
                    Section {
                        Text("Fartlek Audio Coach")
                            .font(.headline)
                        Text("Heart-rate-guided interval training with spoken coaching.")
                        LabeledContent("Version", value: version)
                    }
                }
            }
            .navigationTitle(destination.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            if destination == .purchase && purchaseManager.product == nil {
                await purchaseManager.refresh()
            }
        }
    }

    @ViewBuilder
    private var purchaseContent: some View {
        Section("Full coach") {
            Text("Unlock custom sessions and advanced multi-block workouts with a one-time purchase.")
            if purchaseManager.isPremium {
                Label("The full app is unlocked", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } else if let product = purchaseManager.product {
                Button("Buy for \(product.displayPrice)") {
                    Task {
                        restoreMessage = nil
                        purchaseManager.errorMessage = nil
                        await purchaseManager.purchase()
                    }
                }
                .disabled(purchaseManager.isLoading)
                .accessibilityIdentifier("buyFullCoach")
            } else if !purchaseManager.isLoading {
                Text("Purchase details are unavailable. Check your internet connection and try again.")
                    .foregroundStyle(.secondary)
                Button("Retry") {
                    Task {
                        purchaseManager.errorMessage = nil
                        await purchaseManager.refresh()
                    }
                }
            }
            if purchaseManager.isLoading {
                ProgressView("Contacting the App Store…")
            }
        }
        Section {
            Button("Restore Purchases") {
                Task {
                    purchaseManager.errorMessage = nil
                    restoreMessage = nil
                    await purchaseManager.restore()
                    if purchaseManager.errorMessage == nil {
                        restoreMessage = purchaseManager.isPremium
                            ? "Purchase restored. The full app is unlocked."
                            : "No previous purchase was found for this Apple Account."
                    }
                }
            }
            .disabled(purchaseManager.isLoading)
            .accessibilityIdentifier("restorePurchases")
            if let restoreMessage {
                Text(restoreMessage)
                    .foregroundStyle(.secondary)
            }
            if let error = purchaseManager.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            }
        }
    }

    private var helpContent: some View {
        Group {
            Section("Connect your monitor") {
                Text("Enable Bluetooth and put your monitor into heart-rate broadcasting mode. Open the Monitor selection button and select your device. Start Session becomes available once connected and receiving heart-rate data.")
            }
            Section("Set up a workout") {
                Text("Open the Session selection button to choose a workout and edit warmup minutes, lower and upper heart-rate targets, and iteration count. Targets are percentages of your maximum heart rate.")
                Text("After warmup, slow down to the lower target if needed. Speed up to the upper target, then slow down to the lower target to complete each iteration.")
            }
            Section("Heart rate and audio") {
                Text("Tap the heart-rate number to switch between BPM and percent of maximum. Tap the heart icon to hear the current number when audio is enabled.")
                Text("Use the speaker button at the top right to enable or disable audio. Tap the cue countdown to hear the current number and time until the next heart-rate announcement.")
                Text("In Settings, adjust voice speed, speech interval, resting heart rate, and maximum heart rate. A speech interval of 0 announces every received heart-rate sample; other values specify seconds between announcements.")
            }
            Section("Background use") {
                Text("With a connected monitor sending data, Bluetooth updates can advance the workout and trigger audio while the screen is locked or another app is open. Do not force-quit the app. Background timing depends on iOS and incoming Bluetooth updates.")
            }
            Section("Train safely") {
                Text("Use targets appropriate for your fitness and health. Stop exercising if you feel unwell. This app is a training aid, not a medical device.")
            }
        }
    }

    private var version: String {
        let release = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(release) (\(build))"
    }
}