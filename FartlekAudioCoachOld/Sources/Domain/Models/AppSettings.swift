import Foundation

enum HeartRateDisplayMode: String, Codable {
    case bpm
    case percent
}

struct AppSettings: Codable {
    var audioEnabled: Bool
    var voiceRate: Double
    var heartRateSpeakIntervalSeconds: Int
    var displayMode: HeartRateDisplayMode
    var restHeartRate: Int
    var maxHeartRate: Int
    var autoUpdateRestHeartRate: Bool
    var autoUpdateMaxHeartRate: Bool

    static let `default` = AppSettings(
        audioEnabled: true,
        voiceRate: 0.5,
        heartRateSpeakIntervalSeconds: 20,
        displayMode: .percent,
        restHeartRate: 60,
        maxHeartRate: 185,
        autoUpdateRestHeartRate: false,
        autoUpdateMaxHeartRate: false
    )
}
