import Foundation

struct PyramidWorkout: Identifiable, Codable, Hashable {
    static let maximumBlockCount = 6

    enum ValidationError: Error, Equatable {
        case tooManyBlocks
    }

    let id: UUID
    var name: String
    var warmupSeconds: Int
    private(set) var blocks: [HeartRateInterval]
    var isFavorite: Bool
    var createdAt: Date
    let isBuiltIn: Bool

    init(
        id: UUID = UUID(),
        name: String,
        warmupSeconds: Int = 0,
        blocks: [HeartRateInterval],
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        isBuiltIn: Bool = false
    ) throws {
        guard blocks.count <= Self.maximumBlockCount else {
            throw ValidationError.tooManyBlocks
        }
        self.id = id
        self.name = name
        self.warmupSeconds = warmupSeconds
        self.blocks = blocks
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.isBuiltIn = isBuiltIn
    }

    /// Replaces the blocks atomically, leaving the workout unchanged if the limit is exceeded.
    mutating func setBlocks(_ blocks: [HeartRateInterval]) throws {
        guard blocks.count <= Self.maximumBlockCount else {
            throw ValidationError.tooManyBlocks
        }
        self.blocks = blocks
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, warmupSeconds, blocks, isFavorite, createdAt, isBuiltIn
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let blocks = try container.decode([HeartRateInterval].self, forKey: .blocks)
        guard blocks.count <= Self.maximumBlockCount else {
            throw DecodingError.dataCorruptedError(
                forKey: .blocks,
                in: container,
                debugDescription: "A pyramid workout supports at most \(Self.maximumBlockCount) blocks."
            )
        }
        let name = try container.decode(String.self, forKey: .name)
        let warmupSeconds = try container.decode(Int.self, forKey: .warmupSeconds)
        // Earlier files seeded templates without a provenance flag. Match their full
        // structure, not their random UUIDs. Newly saved custom workouts explicitly store false.
        let isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn)
            ?? Self.standardTemplates.contains { template in
                template.name == name && template.warmupSeconds == warmupSeconds
                    && template.blocks.count == blocks.count
                    && zip(template.blocks, blocks).allSatisfy {
                        $0.iterations == $1.iterations && $0.lowerHR == $1.lowerHR && $0.upperHR == $1.upperHR
                    }
            }
        try self.init(
            id: container.decode(UUID.self, forKey: .id),
            name: name,
            warmupSeconds: warmupSeconds,
            blocks: blocks,
            isFavorite: container.decode(Bool.self, forKey: .isFavorite),
            createdAt: container.decode(Date.self, forKey: .createdAt),
            isBuiltIn: isBuiltIn
        )
    }
}

extension PyramidWorkout {
    func asSessionTemplate() -> SessionTemplate {
        SessionTemplate(
            id: id,
            name: name,
            blocks: blocks.map {
                SessionBlock(id: $0.id, repetitions: $0.iterations,
                             lowerTargetPercent: $0.lowerHR, upperTargetPercent: $0.upperHR)
            },
            isBuiltin: isBuiltIn,
            warmupMinutes: Int(ceil(Double(warmupSeconds) / 60)),
            warmupSeconds: warmupSeconds
        )
    }

    // These fixed templates are known to satisfy the six-block limit.
    static let flatFartlek = try! PyramidWorkout(
        name: "Flat Fartlek",
        warmupSeconds: 600,
        blocks: [HeartRateInterval(iterations: 8, lowerHR: 70, upperHR: 80)],
        isBuiltIn: true
    )

    static let classicPyramid = try! PyramidWorkout(
        name: "Classic Pyramid",
        warmupSeconds: 600,
        blocks: [
            HeartRateInterval(iterations: 6, lowerHR: 70, upperHR: 80),
            HeartRateInterval(iterations: 3, lowerHR: 75, upperHR: 85),
            HeartRateInterval(iterations: 1, lowerHR: 85, upperHR: 95),
            HeartRateInterval(iterations: 3, lowerHR: 75, upperHR: 85),
            HeartRateInterval(iterations: 6, lowerHR: 70, upperHR: 80)
        ],
        isBuiltIn: true
    )

    static let staircase = try! PyramidWorkout(
        name: "Staircase",
        warmupSeconds: 600,
        blocks: [
            HeartRateInterval(iterations: 3, lowerHR: 65, upperHR: 75),
            HeartRateInterval(iterations: 3, lowerHR: 70, upperHR: 80),
            HeartRateInterval(iterations: 3, lowerHR: 75, upperHR: 85),
            HeartRateInterval(iterations: 3, lowerHR: 80, upperHR: 90)
        ],
        isBuiltIn: true
    )

    static let thresholdWaves = try! PyramidWorkout(
        name: "Threshold Waves",
        warmupSeconds: 600,
        blocks: [
            HeartRateInterval(iterations: 2, lowerHR: 75, upperHR: 85),
            HeartRateInterval(iterations: 2, lowerHR: 80, upperHR: 90),
            HeartRateInterval(iterations: 2, lowerHR: 75, upperHR: 85),
            HeartRateInterval(iterations: 2, lowerHR: 80, upperHR: 90),
            HeartRateInterval(iterations: 2, lowerHR: 75, upperHR: 85),
            HeartRateInterval(iterations: 2, lowerHR: 80, upperHR: 90)
        ],
        isBuiltIn: true
    )

    static let standardTemplates: [PyramidWorkout] = [flatFartlek, classicPyramid, staircase, thresholdWaves]

    /// A fresh, unsaved draft; callers can present an editor before committing it to storage.
    static func newCustomPyramid() throws -> PyramidWorkout {
        try PyramidWorkout(
            name: "Custom workout",
            warmupSeconds: 600,
            blocks: (0..<maximumBlockCount).map { _ in
                HeartRateInterval(iterations: 3, lowerHR: 70, upperHR: 85)
            }
        )
    }
}
