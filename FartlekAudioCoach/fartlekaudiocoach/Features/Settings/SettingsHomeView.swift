import SwiftUI
import UIKit

struct SettingsHomeView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var settings: AppSettings
    @State private var isSpeakIntervalValid = true
    @State private var isRestHeartRateValid = true
    @State private var isMaxHeartRateValid = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Audio") {
                    Stepper("Voice speed: \(settings.voiceRate, specifier: "%.2f")", value: $settings.voiceRate, in: 0.1...1.0, step: 0.05)
                    WorkoutNumberInput(title: "Speak interval", unit: "s",
                                       value: $settings.heartRateSpeakIntervalSeconds, range: 0...120,
                                       isValid: $isSpeakIntervalValid, identifier: "settingsSpeakInterval")
                    if settings.heartRateSpeakIntervalSeconds == 0 {
                        Text("Every received sample (when speech is not busy).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Heart Rate Baseline") {
                    WorkoutNumberInput(title: "Rest HR", unit: "bpm",
                                       value: $settings.restHeartRate, range: 30...100,
                                       isValid: $isRestHeartRateValid, identifier: "settingsRestHeartRate")
                    WorkoutNumberInput(title: "Max HR", unit: "bpm",
                                       value: $settings.maxHeartRate, range: 120...220,
                                       isValid: $isMaxHeartRateValid, identifier: "settingsMaxHeartRate")
                    
                    Divider()
                    
                    Toggle("Auto-update rest HR", isOn: $settings.autoUpdateRestHeartRate)
                    Toggle("Auto-update max HR", isOn: $settings.autoUpdateMaxHeartRate)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismissKeyboard()
                        dismiss()
                    }
                    .disabled(!isSpeakIntervalValid || !isRestHeartRateValid || !isMaxHeartRateValid)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                }
            }
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
