import Foundation

enum HeartRateZone: String, CaseIterable, Identifiable {
    case moderate, weightControl, aerobic, anaerobic, vo2Max

    var id: String { rawValue }

    static func zone(forPercent percent: Int) -> HeartRateZone {
        switch percent {
        case ..<60: return .moderate
        case 60..<70: return .weightControl
        case 70..<80: return .aerobic
        case 80..<90: return .anaerobic
        default: return .vo2Max
        }
    }

    var title: String {
        switch self {
        case .moderate: return "Moderate activity (warm up)"
        case .weightControl: return "Weight control (fitness)"
        case .aerobic: return "Aerobic (endurance)"
        case .anaerobic: return "Anaerobic (hard effort)"
        case .vo2Max: return "VO₂ max (maximum effort)"
        }
    }

    var shortTitle: String {
        switch self {
        case .moderate: return "Moderate"
        case .weightControl: return "Weight control"
        case .aerobic: return "Aerobic"
        case .anaerobic: return "Anaerobic"
        case .vo2Max: return "VO₂ max"
        }
    }

    var lowerPercent: Int {
        switch self {
        case .moderate: return 0
        case .weightControl: return 60
        case .aerobic: return 70
        case .anaerobic: return 80
        case .vo2Max: return 90
        }
    }

    var upperPercent: Int? {
        switch self {
        case .moderate: return 60
        case .weightControl: return 70
        case .aerobic: return 80
        case .anaerobic: return 90
        case .vo2Max: return nil
        }
    }

    var percentSummary: String {
        if self == .moderate { return "Below 60% of maximum HR" }
        guard let upperPercent else { return "90% of maximum HR and above" }
        return "\(lowerPercent)% to below \(upperPercent)% of maximum HR"
    }

    func bpmSummary(maxHeartRate: Int) -> String {
        guard maxHeartRate > 0 else { return "Set your maximum heart rate in Settings." }
        // Round thresholds upward so the table matches integer-percent conversion
        // used by the live display (e.g. 90% of 185 begins at 167 BPM).
        let lower = (maxHeartRate * lowerPercent + 99) / 100
        guard let upperPercent else { return "\(lower) BPM and above" }
        let upper = (maxHeartRate * upperPercent + 99) / 100
        if self == .moderate { return "Below \(upper) BPM" }
        return "\(lower)–\(upper - 1) BPM"
    }

    var explanation: String {
        switch self {
        case .moderate: return "An easy effort for warming up, cooling down, and recovery. Breathing should generally feel comfortable."
        case .weightControl: return "A light fitness effort that can usually be sustained comfortably. The traditional HeartMonitor name is Weight control; this zone does not guarantee weight loss."
        case .aerobic: return "A sustained endurance effort with deeper breathing, using a mixture of fat and carbohydrates for energy."
        case .anaerobic: return "A hard effort with heavier breathing, typically suited to shorter intervals rather than prolonged exercise."
        case .vo2Max: return "A very high effort, typically used for short, demanding intervals. A percentage-based zone is only an estimate, not a measurement of VO₂ max."
        }
    }
}
