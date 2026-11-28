import Foundation

/// Mirrors Corrate's calculateHrmPercent logic.
/// All conversion between % and BPM uses the user's configured max heart rate.
enum HeartRateConverter {
    /// Returns percent (0-100) from a BPM value given max heart rate.
    static func percent(from bpm: Int, maxHeartRate: Int) -> Int {
        guard maxHeartRate > 0 else { return 0 }
        return bpm * 100 / maxHeartRate
    }

    /// Returns BPM from a percent (0-100) value given max heart rate.
    static func bpm(from percent: Int, maxHeartRate: Int) -> Int {
        return percent * maxHeartRate / 100
    }
}
