import CoreBluetooth
import Foundation

@MainActor
final class CoreBluetoothHeartRateService: NSObject, HeartRateService {
    private static let heartRateServiceUUID = CBUUID(string: "180D")
    private static let heartRateMeasurementUUID = CBUUID(string: "2A37")

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var discoveredDevices: [HeartRateDevice] = []
    private var peripheralsByID: [UUID: CBPeripheral] = [:]
    private var settingsStore: SettingsStore?
    private var connectionState: HeartRateConnectionState = .disconnected {
        didSet {
            if oldValue != connectionState {
                onConnectionStateChanged?(connectionState)
            }
        }
    }

    var onConnectionStateChanged: ((HeartRateConnectionState) -> Void)? {
        didSet {
            // A view may subscribe after Bluetooth has already connected.
            onConnectionStateChanged?(connectionState)
        }
    }
    var onSample: ((HeartRateSample) -> Void)?
    var onDevicesChanged: (([HeartRateDevice]) -> Void)?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
        // Check for already connected peripherals after a short delay to allow the central manager to initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkForConnectedPeripherals()
        }
    }
    
    func setSettingsStore(_ store: SettingsStore) {
        self.settingsStore = store
    }
    
    private func checkForConnectedPeripherals() {
        NSLog("🔵 HeartRateService: checkForConnectedPeripherals() called")
        guard centralManager.state == .poweredOn else { return }
        let connectedPeripherals = centralManager.retrieveConnectedPeripherals(withServices: [Self.heartRateServiceUUID])
        NSLog("🔵 HeartRateService: Found \(connectedPeripherals.count) already connected peripherals with Heart Rate service")
        
        guard let peripheral = connectedPeripherals.first else {
            NSLog("🔵 HeartRateService: No connected peripherals found")
            return
        }
        
        NSLog("🔵 HeartRateService: Found connected peripheral: \(peripheral.name ?? "Unknown") - \(peripheral.identifier), state: \(peripheral.state.rawValue)")
        
        // Store the peripheral for potential connection
        let device = device(from: peripheral)
        peripheralsByID[device.id] = peripheral
        
        // If peripheral is already connected, set it up directly
        if peripheral.state == .connected {
            NSLog("🔵 HeartRateService: Peripheral is already connected, setting up...")
            setupPeripheral(peripheral, device: device)
        } else {
            // If not connected, explicitly connect it (this will trigger didConnect)
            NSLog("🔵 HeartRateService: Peripheral not in connected state, calling centralManager.connect()")
            connectedPeripheral = peripheral
            peripheral.delegate = self
            connectionState = .connecting(device)
            centralManager.connect(peripheral)
        }
    }

    func startScan() {
        NSLog("🔵 HeartRateService: startScan() called")
        guard centralManager.state == .poweredOn else {
            NSLog("❌ HeartRateService: Cannot scan, centralManager state: \(centralManager.state.rawValue)")
            return
        }
        discoveredDevices = []
        onDevicesChanged?(discoveredDevices)
        NSLog("🔵 HeartRateService: Starting scan for Heart Rate service")
        centralManager.scanForPeripherals(withServices: [Self.heartRateServiceUUID])
        if connectedPeripheral == nil {
            connectionState = .scanning
        }
    }

    func stopScan() {
        NSLog("🔵 HeartRateService: stopScan() called")
        centralManager.stopScan()
        if case .scanning = connectionState {
            connectionState = .disconnected
        }
    }

    func connect(to device: HeartRateDevice) {
        NSLog("🔵 HeartRateService: connect(to:) called for device \(device.name) - \(device.id)")
        guard centralManager.state == .poweredOn else { return }
        guard let peripheral = peripheralsByID[device.id]
                ?? centralManager.retrievePeripherals(withIdentifiers: [device.id]).first else {
            NSLog("❌ HeartRateService: Device not found in peripheralsByID")
            return
        }
        NSLog("🔵 HeartRateService: Found peripheral in cache, initiating connection")
        centralManager.stopScan()
        connectedPeripheral = peripheral
        peripheral.delegate = self
        connectionState = .connecting(device)
        centralManager.connect(peripheral)
    }

    func disconnect() {
        if let connectedPeripheral {
            centralManager.cancelPeripheralConnection(connectedPeripheral)
        } else {
            centralManager.stopScan()
            connectionState = .disconnected
        }
        
        // Clear the saved device
        Task {
            await settingsStore?.clearLastConnectedDevice()
        }
    }
    
    func checkForExistingConnection() {
        checkForConnectedPeripherals()
    }
    
    private func setupPeripheral(_ peripheral: CBPeripheral, device: HeartRateDevice) {
        NSLog("🔵 HeartRateService: setupPeripheral() called for \(device.name) - \(device.id)")
        connectedPeripheral = peripheral
        peripheral.delegate = self
        connectionState = .connected(device)
        NSLog("🔵 HeartRateService: Connection state changed to .connected")
        
        // Save the device for auto-reconnection next time
        Task {
            await settingsStore?.saveLastConnectedDevice(device)
            NSLog("🔵 HeartRateService: Saved device to settings")
        }
        
        // If services are already discovered, set up notifications directly
        if let services = peripheral.services, !services.isEmpty {
            NSLog("🔵 HeartRateService: Services already discovered: \(services.count) service(s)")
            peripheral.services?.forEach { service in
                guard service.uuid == Self.heartRateServiceUUID else { return }
                NSLog("🔵 HeartRateService: Found Heart Rate service")
                if let characteristics = service.characteristics, !characteristics.isEmpty {
                    NSLog("🔵 HeartRateService: Characteristics already discovered: \(characteristics.count) characteristic(s)")
                    characteristics.forEach { characteristic in
                        guard characteristic.uuid == Self.heartRateMeasurementUUID else { return }
                        NSLog("🔵 HeartRateService: Found Heart Rate Measurement characteristic, enabling notifications")
                        peripheral.setNotifyValue(true, for: characteristic)
                    }
                } else {
                    NSLog("🔵 HeartRateService: No characteristics discovered yet, discovering...")
                    peripheral.discoverCharacteristics([Self.heartRateMeasurementUUID], for: service)
                }
            }
        } else {
            NSLog("🔵 HeartRateService: Services not discovered yet, discovering...")
            peripheral.discoverServices([Self.heartRateServiceUUID])
        }
    }

    private func parseHeartRate(from data: Data) -> Int? {
        guard let flags = data.first else { return nil }
        if flags & 0x01 != 0 {
            guard data.count >= 3 else { return nil }
            return Int(data[1]) | (Int(data[2]) << 8)
        }
        guard data.count >= 2 else { return nil }
        return Int(data[1])
    }

    private func device(from peripheral: CBPeripheral) -> HeartRateDevice {
        HeartRateDevice(id: peripheral.identifier, name: peripheral.name ?? "Heart-rate monitor")
    }
}

extension CoreBluetoothHeartRateService: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            NSLog("🔵 HeartRateService: CBCentralManager state changed to \(central.state.rawValue)")
            if central.state == .poweredOn {
                checkForConnectedPeripherals()
            } else if central.state == .poweredOff {
                connectedPeripheral = nil
                connectionState = .disconnected
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        NSLog("🔵 HeartRateService: Discovered peripheral: \(peripheral.name ?? "Unknown") - \(peripheral.identifier)")
        let device = device(from: peripheral)
        guard !discoveredDevices.contains(where: { $0.id == device.id }) else { return }
        peripheralsByID[device.id] = peripheral
        discoveredDevices.append(device)
        NSLog("🔵 HeartRateService: Added to discoveredDevices, total: \(discoveredDevices.count)")
        onDevicesChanged?(discoveredDevices)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        NSLog("🔵 HeartRateService: didConnect delegate called for \(peripheral.name ?? "Unknown"), state: \(peripheral.state.rawValue)")
        let device = device(from: peripheral)
        // Ensure device is in cache
        peripheralsByID[device.id] = peripheral
        setupPeripheral(peripheral, device: device)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        NSLog("❌ HeartRateService: didFailToConnect: \(error?.localizedDescription ?? "unknown error")")
        guard peripheral.identifier == connectedPeripheral?.identifier else { return }
        connectedPeripheral = nil
        connectionState = .disconnected
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        NSLog("🔵 HeartRateService: didDisconnectPeripheral: \(peripheral.name ?? "Unknown")")
        guard peripheral.identifier == connectedPeripheral?.identifier else { return }
        connectedPeripheral = nil
        connectionState = .disconnected
    }
}

extension CoreBluetoothHeartRateService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        NSLog("🔵 HeartRateService: didDiscoverServices for \(peripheral.name ?? "Unknown"), error: \(error?.localizedDescription ?? "none")")
        guard error == nil else { return }
        NSLog("🔵 HeartRateService: Services discovered: \(peripheral.services?.count ?? 0)")
        peripheral.services?.forEach { service in
            NSLog("🔵 HeartRateService: Service: \(service.uuid)")
            guard service.uuid == Self.heartRateServiceUUID else { return }
            NSLog("🔵 HeartRateService: Found Heart Rate service, discovering characteristics...")
            peripheral.discoverCharacteristics([Self.heartRateMeasurementUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        NSLog("🔵 HeartRateService: didDiscoverCharacteristics for service \(service.uuid), error: \(error?.localizedDescription ?? "none")")
        guard error == nil else { return }
        NSLog("🔵 HeartRateService: Characteristics discovered: \(service.characteristics?.count ?? 0)")
        service.characteristics?.forEach { characteristic in
            NSLog("🔵 HeartRateService: Characteristic: \(characteristic.uuid)")
            guard characteristic.uuid == Self.heartRateMeasurementUUID else { return }
            NSLog("🔵 HeartRateService: Found Heart Rate Measurement characteristic, enabling notifications...")
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard peripheral.identifier == connectedPeripheral?.identifier,
              peripheral.state == .connected,
              error == nil,
              characteristic.uuid == Self.heartRateMeasurementUUID,
              let data = characteristic.value,
              let bpm = parseHeartRate(from: data) else {
            if error != nil {
                NSLog("❌ HeartRateService: didUpdateValue error: \(error?.localizedDescription ?? "unknown")")
            }
            return
        }

        NSLog("🔵 HeartRateService: ❤️ Heart rate received: \(bpm) BPM")
        connectionState = .connected(device(from: peripheral))
        let sample = HeartRateSample(
            bpm: bpm,
            percent: HeartRateConverter.percent(from: bpm, maxHeartRate: AppSettings.default.maxHeartRate),
            timestamp: Date()
        )
        onSample?(sample)
    }
}
