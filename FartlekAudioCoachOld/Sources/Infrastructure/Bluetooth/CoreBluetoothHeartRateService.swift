import Foundation

final class CoreBluetoothHeartRateService: HeartRateService {
    var onConnectionStateChanged: ((HeartRateConnectionState) -> Void)?
    var onSample: ((HeartRateSample) -> Void)?

    func startScan() {
        // TODO: Port tested BLE scan/discovery logic from Corrate.
        onConnectionStateChanged?(.scanning)
    }

    func stopScan() {
        onConnectionStateChanged?(.disconnected)
    }

    func connect(to device: HeartRateDevice) {
        // TODO: Port connection + characteristic subscription logic from Corrate.
        onConnectionStateChanged?(.connecting(device))
        onConnectionStateChanged?(.connected(device))
    }

    func disconnect() {
        onConnectionStateChanged?(.disconnected)
    }
}
