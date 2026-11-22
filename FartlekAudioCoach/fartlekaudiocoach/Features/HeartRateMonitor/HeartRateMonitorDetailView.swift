import SwiftUI

struct HeartRateMonitorDetailView: View {
    let device: HeartRateDevice
    @ObservedObject var model: RunnerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Monitor") {
                    LabeledContent("Name", value: device.name)
                    LabeledContent("Status", value: status)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bluetooth identifier")
                        Text(device.id.uuidString)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                Section("Current reading") {
                    if isConnected, !model.isHeartRateMissing, let sample = model.latestSample {
                        LabeledContent("Heart rate", value: "\(sample.bpm) BPM")
                    } else {
                        Text(isConnected ? "Waiting for fresh heart rate data." : "No current reading — monitor is not connected.")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Bluetooth protocol") {
                    LabeledContent("Connection type", value: "Bluetooth Low Energy")
                    LabeledContent("Heart Rate service", value: "180D")
                    LabeledContent("Heart Rate Measurement", value: "2A37")
                }
                Section("Hardware specifications") {
                    ForEach(HeartRateDeviceSpecifications.textFields.keys.sorted(), id: \.self) { uuid in
                        if let value = model.deviceSpecifications[device.id]?.values[uuid] {
                            LabeledContent(HeartRateDeviceSpecifications.textFields[uuid] ?? uuid, value: value)
                        }
                    }
                    if let battery = model.deviceSpecifications[device.id]?.values["2A19"] {
                        LabeledContent("Battery level", value: battery)
                    }
                    if let location = model.deviceSpecifications[device.id]?.values["2A38"] {
                        LabeledContent("Sensor location", value: location)
                    }
                    Text("Fields appear as the monitor supplies them. Missing fields may be unsupported or unavailable. Battery level is updated when the monitor sends a notification.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Monitor Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var isConnected: Bool {
        if case .connected(let connected) = model.connectionState {
            return connected.id == device.id
        }
        return false
    }

    private var status: String {
        switch model.connectionState {
        case .connected(let connected) where connected.id == device.id:
            return model.isHeartRateMissing ? "Connected — no heart rate received" : "Connected"
        case .connecting(let connecting) where connecting.id == device.id:
            return "Connecting"
        default:
            return "Not connected"
        }
    }
}
