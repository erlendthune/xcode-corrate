import Foundation

protocol SettingsStore {
    func loadSettings() -> AppSettings
    func saveSettings(_ settings: AppSettings)
}
