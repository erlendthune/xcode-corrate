import Foundation

final class UserDefaultsSettingsStore: SettingsStore, @unchecked Sendable {
    private let key = "app_settings"
    private let deviceIdKey = "last_connected_device_id"
    private let deviceNameKey = "last_connected_device_name"

    func loadSettings() async -> AppSettings {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            var settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return .default
        }
        
        // Migration: Fix voiceRate if it's at the old max default of 1.0
        if settings.voiceRate >= 0.9 {
            settings.voiceRate = 0.35  // Use new default
        }
        
        return settings
    }

    func saveSettings(_ settings: AppSettings) async {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
    
    func saveLastConnectedDevice(_ device: HeartRateDevice) async {
        UserDefaults.standard.set(device.id.uuidString, forKey: deviceIdKey)
        UserDefaults.standard.set(device.name, forKey: deviceNameKey)
    }
    
    func loadLastConnectedDevice() async -> HeartRateDevice? {
        guard let idString = UserDefaults.standard.string(forKey: deviceIdKey),
              let uuid = UUID(uuidString: idString),
              let name = UserDefaults.standard.string(forKey: deviceNameKey) else {
            return nil
        }
        return HeartRateDevice(id: uuid, name: name)
    }
    
    func clearLastConnectedDevice() async {
        UserDefaults.standard.removeObject(forKey: deviceIdKey)
        UserDefaults.standard.removeObject(forKey: deviceNameKey)
    }
}
