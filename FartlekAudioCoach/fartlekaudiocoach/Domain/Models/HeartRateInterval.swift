import Foundation

/// A repeated interval between two targets, expressed as percentages of maximum heart rate.
struct HeartRateInterval: Identifiable, Codable, Hashable {
    let id: UUID
    var iterations: Int
    var lowerHR: Int
    var upperHR: Int

    init(id: UUID = UUID(), iterations: Int, lowerHR: Int, upperHR: Int) {
        self.id = id
        self.iterations = iterations
        self.lowerHR = lowerHR
        self.upperHR = upperHR
    }
}