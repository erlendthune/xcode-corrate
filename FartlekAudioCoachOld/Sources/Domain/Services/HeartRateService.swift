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

protocol HeartRateService: AnyObject {
    var onConnectionStateChanged: ((HeartRateConnectionState) -> Void)? { get set }
    var onSample: ((HeartRateSample) -> Void)? { get set }

    func startScan()
    func stopScan()
    func connect(to device: HeartRateDevice)
    func disconnect()
}
