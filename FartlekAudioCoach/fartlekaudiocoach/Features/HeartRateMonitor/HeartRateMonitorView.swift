import SwiftUI

struct HeartRateMonitorView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var model: RunnerViewModel
    @State private var isScanning = false
    @State private var deviceToInspect: HeartRateDevice?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    if isScanning {
                        ProgressView()
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundStyle(.blue)
                    }
                    
                    Text(headerTitle)
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: startScan) {
                        Label("Scan", systemImage: "arrow.clockwise")
                            .labelStyle(.iconOnly)
                            .font(.headline)
                    }
                    .disabled(isScanning)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding()
                
                ScrollView {
                    VStack(spacing: 12) {
                        if model.availableDevices.isEmpty && !isScanning {
                            VStack(spacing: 12) {
                                Image(systemName: "heart.slash")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.gray)
                                Text("No devices found")
                                    .font(.headline)
                                Text("Tap Scan to find heart rate monitors")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                        } else {
                            ForEach(model.availableDevices, id: \.id) { device in
                                DeviceCard(
                                    device: device,
                                    isSelected: isDeviceConnected(device.id),
                                    onSelect: {
                                        if isDeviceConnected(device.id) {
                                            deviceToInspect = device
                                        } else {
                                            model.connect(to: device)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Heart Rate Monitor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(item: $deviceToInspect) { device in
            HeartRateMonitorDetailView(device: device, model: model)
        }
        .onAppear {
            // Auto-start scanning only if not already connected to a device
            if case .disconnected = model.connectionState {
                startScan()
            }
        }
        .onDisappear {
            model.stopScan()
        }
    }

    private func startScan() {
        isScanning = true
        model.connect()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            isScanning = false
            model.stopScan()
        }
    }

    private var headerTitle: String {
        isScanning ? "Scanning for devices..." : "Heart Rate Monitors"
    }

    private func isDeviceConnected(_ deviceId: UUID) -> Bool {
        if case .connected(let device) = model.connectionState {
            return device.id == deviceId
        }
        return false
    }
}

private struct DeviceCard: View {
    let device: HeartRateDevice
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(device.id.uuidString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "heart.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(.gray)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .foregroundStyle(.primary)
        .accessibilityHint(isSelected ? "View monitor details" : "Connect to this monitor")
    }
}

#Preview {
    HeartRateMonitorView(model: RunnerViewModel(environment: AppEnvironment.bootstrap()))
}
