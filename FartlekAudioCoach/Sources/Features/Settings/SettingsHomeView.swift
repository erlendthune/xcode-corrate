import SwiftUI

struct SettingsHomeView: View {
    let settingsStore: SettingsStore
    @State private var settings = AppSettings.default

    var body: some View {
        NavigationStack {
            Form {
                Toggle("Audio enabled", isOn: $settings.audioEnabled)
                Picker("Display mode", selection: $settings.displayMode) {
                    Text("Percent").tag(HeartRateDisplayMode.percent)
                    Text("BPM").tag(HeartRateDisplayMode.bpm)
                }
                .pickerStyle(.segmented)

                Stepper("Voice speed: \(settings.voiceRate, specifier: "%.2f")", value: $settings.voiceRate, in: 0.1...1.0, step: 0.05)
                Stepper("Speak interval: \(settings.heartRateSpeakIntervalSeconds)s", value: $settings.heartRateSpeakIntervalSeconds, in: 5...120, step: 5)

                Toggle("Auto-update rest HR", isOn: $settings.autoUpdateRestHeartRate)
                Toggle("Auto-update max HR", isOn: $settings.autoUpdateMaxHeartRate)
            }
            .navigationTitle("Settings")
            .task {
                settings = settingsStore.loadSettings()
            }
            .onChange(of: settings) { _, updated in
                settingsStore.saveSettings(updated)
            }
        }
    }
}
