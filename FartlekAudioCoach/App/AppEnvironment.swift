import Foundation

final class AppEnvironment: ObservableObject {
    let heartRateService: HeartRateService
    let sessionStore: SessionStore
    let settingsStore: SettingsStore
    let sessionEngine: SessionEngine

    private init(
        heartRateService: HeartRateService,
        sessionStore: SessionStore,
        settingsStore: SettingsStore,
        sessionEngine: SessionEngine
    ) {
        self.heartRateService = heartRateService
        self.sessionStore = sessionStore
        self.settingsStore = settingsStore
        self.sessionEngine = sessionEngine
    }

    static func bootstrap() -> AppEnvironment {
        let heartRateService = CoreBluetoothHeartRateService()
        let sessionStore = FileSessionStore()
        let settingsStore = UserDefaultsSettingsStore()
        let sessionEngine = DefaultSessionEngine()

        return AppEnvironment(
            heartRateService: heartRateService,
            sessionStore: sessionStore,
            settingsStore: settingsStore,
            sessionEngine: sessionEngine
        )
    }
}
