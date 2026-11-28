import Foundation

// Targets in SessionBlock are always stored as heart rate percentages (0-100).
// Conversion to BPM for display and comparison is done at runtime using AppSettings.maxHeartRate.
// Formula: bpm = percent * maxHeartRate / 100

struct SessionTemplate: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var notes: String
    var blocks: [SessionBlock]
    var isBuiltin: Bool
    var isPremium: Bool

    init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        blocks: [SessionBlock],
        isBuiltin: Bool = false,
        isPremium: Bool = false
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.blocks = blocks
        self.isBuiltin = isBuiltin
        self.isPremium = isPremium
    }
}

/// A single block within a session.
/// lowerTargetPercent and upperTargetPercent are always stored as percent (0-100).
struct SessionBlock: Identifiable, Codable, Equatable {
    let id: UUID
    /// Number of warmup repetitions before the main iterations begin (0 means no warmup block).
    var warmupRepetitions: Int
    var repetitions: Int
    var lowerTargetPercent: Int
    var upperTargetPercent: Int

    init(
        id: UUID = UUID(),
        warmupRepetitions: Int = 0,
        repetitions: Int,
        lowerTargetPercent: Int,
        upperTargetPercent: Int
    ) {
        self.id = id
        self.warmupRepetitions = warmupRepetitions
        self.repetitions = repetitions
        self.lowerTargetPercent = lowerTargetPercent
        self.upperTargetPercent = upperTargetPercent
    }
}
