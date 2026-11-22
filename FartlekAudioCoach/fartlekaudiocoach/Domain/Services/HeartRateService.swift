import Foundation

struct HeartRateDevice: Equatable, Identifiable {
    let id: UUID
    let name: String
}

struct HeartRateDeviceSpecifications: Equatable {
    static let textFields: [String: String] = [
        "2A24": "Model number",
        "2A25": "Serial number",
        "2A26": "Firmware revision",
        "2A27": "Hardware revision",
        "2A28": "Software revision",
        "2A29": "Manufacturer"
    ]

    private(set) var values: [String: String] = [:]

    mutating func update(uuid: String, data: Data) {
        let key = uuid.uppercased()
        if Self.textFields[key] != nil {
            guard let text = String(data: data, encoding: .utf8) else { return }
            let value = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
            guard !value.isEmpty else { return }
            values[key] = value
        } else if key == "2A19" {
            guard let level = data.first, level <= 100 else { return }
            values[key] = "\(level)%"
        } else if key == "2A38" {
            let locations = ["Other", "Chest", "Wrist", "Finger", "Hand", "Ear lobe", "Foot"]
            guard let location = data.first, Int(location) < locations.count else { return }
            values[key] = locations[Int(location)]
        }
    }
}

enum HeartRateConnectionState: Equatable {
    case disconnected
    case scanning
    case connecting(HeartRateDevice)
    case connected(HeartRateDevice)
}

@MainActor
protocol HeartRateService: AnyObject {
    var onConnectionStateChanged: ((HeartRateConnectionState) -> Void)? { get set }
    var onSample: ((HeartRateSample) -> Void)? { get set }
    var onDevicesChanged: (([HeartRateDevice]) -> Void)? { get set }
    var onSpecificationsChanged: ((UUID, HeartRateDeviceSpecifications) -> Void)? { get set }

    func startScan()
    func stopScan()
    func connect(to device: HeartRateDevice)
    func disconnect()
    func checkForExistingConnection()
}
