import Foundation

struct HeartRateDevice: Equatable {
    let id: UUID
    let name: String
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

    func startScan()
    func stopScan()
    func connect(to device: HeartRateDevice)
    func disconnect()
    func checkForExistingConnection()
}
