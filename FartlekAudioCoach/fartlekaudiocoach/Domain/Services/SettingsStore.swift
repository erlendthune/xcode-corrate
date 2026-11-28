import Foundation

protocol SettingsStore: Sendable {
    func loadSettings() async -> AppSettings
    func saveSettings(_ settings: AppSettings) async
    func saveLastConnectedDevice(_ device: HeartRateDevice) async
    func loadLastConnectedDevice() async -> HeartRateDevice?
    func clearLastConnectedDevice() async
}
