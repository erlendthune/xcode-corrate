import SwiftUI

struct SettingsHomeView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var settings: AppSettings

    var body: some View {
        NavigationStack {
            Form {
                Section("Audio") {
                    Stepper("Voice speed: \(settings.voiceRate, specifier: "%.2f")", value: $settings.voiceRate, in: 0.1...1.0, step: 0.05)
                    Stepper(settings.heartRateSpeakIntervalSeconds == 0
                            ? "Speak interval: Every received sample"
                            : "Speak interval: \(settings.heartRateSpeakIntervalSeconds)s",
                            value: $settings.heartRateSpeakIntervalSeconds, in: 0...120, step: 1)
                }

                Section("Heart Rate Baseline") {
                    Stepper("Rest HR: \(settings.restHeartRate) bpm", value: $settings.restHeartRate, in: 30...100, step: 1)
                    Stepper("Max HR: \(settings.maxHeartRate) bpm", value: $settings.maxHeartRate, in: 120...220, step: 1)
                    
                    Divider()
                    
                    Toggle("Auto-update rest HR", isOn: $settings.autoUpdateRestHeartRate)
                    Toggle("Auto-update max HR", isOn: $settings.autoUpdateMaxHeartRate)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
