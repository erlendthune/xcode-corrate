import SwiftUI
import Combine

final class AppEnvironment: ObservableObject {
    let heartRateService: HeartRateService
    let sessionStore: SessionStore
    let workoutStorageManager: WorkoutStorageManager
    let settingsStore: SettingsStore
    let sessionEngine: SessionEngine
    let audioCoach: AudioCoach
    let purchaseManager: PurchaseManager
    @Published var selectedSession: SessionTemplate?
    @Published var selectedDevice: HeartRateDevice?

    private init(
        heartRateService: HeartRateService,
        sessionStore: SessionStore,
        workoutStorageManager: WorkoutStorageManager,
        settingsStore: SettingsStore,
        sessionEngine: SessionEngine,
        audioCoach: AudioCoach,
        purchaseManager: PurchaseManager
    ) {
        self.heartRateService = heartRateService
        self.sessionStore = sessionStore
        self.workoutStorageManager = workoutStorageManager
        self.settingsStore = settingsStore
        self.sessionEngine = sessionEngine
        self.audioCoach = audioCoach
        self.purchaseManager = purchaseManager
        self.selectedSession = nil
        self.selectedDevice = nil
    }

    static func bootstrap() -> AppEnvironment {
        let settingsStore = UserDefaultsSettingsStore()
        let heartRateService = CoreBluetoothHeartRateService()
        // Set the settings store on the service for device persistence
        heartRateService.setSettingsStore(settingsStore)
        
        return AppEnvironment(
            heartRateService: heartRateService,
            sessionStore: FileSessionStore(),
            workoutStorageManager: WorkoutStorageManager(),
            settingsStore: settingsStore,
            sessionEngine: DefaultSessionEngine(),
            audioCoach: AVSpeechAudioCoach(),
            purchaseManager: PurchaseManager()
        )
    }
}
