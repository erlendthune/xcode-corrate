import Combine
import Foundation

@MainActor
final class PyramidWorkoutEditorModel: ObservableObject {
    @Published var workout: PyramidWorkout
    @Published var saveName: String
    @Published var errorMessage: String?
    @Published private(set) var saveCount = 0

    private let storageManager: WorkoutStorageManager
    private var savedSnapshot: PyramidWorkout

    init(workout: PyramidWorkout, storageManager: WorkoutStorageManager) {
        self.workout = workout
        self.storageManager = storageManager
        self.saveName = workout.name
        self.savedSnapshot = workout
    }

    var trimmedName: String {
        saveName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasUnsavedChanges: Bool {
        workout != savedSnapshot || trimmedName != savedSnapshot.name
    }

    func discardChanges() {
        workout = savedSnapshot
        saveName = savedSnapshot.name
        errorMessage = nil
    }

    var canDeleteWorkout: Bool {
        !workout.isBuiltIn && storageManager.workouts.contains { $0.id == workout.id && !$0.isBuiltIn }
    }

    @discardableResult
    func deleteWorkout() -> Bool {
        guard canDeleteWorkout else {
            errorMessage = "Only saved custom workouts can be deleted."
            return false
        }
        guard storageManager.deleteWorkout(id: workout.id) else {
            errorMessage = storageManager.lastError?.localizedDescription ?? "Unable to delete workout. Please try again."
            return false
        }
        errorMessage = nil
        return true
    }

    var validationMessage: String? {
        guard workout.warmupSeconds >= 0 else { return "Warmup cannot be negative." }
        guard !workout.blocks.isEmpty else { return "Add at least one interval block." }
        guard workout.blocks.allSatisfy({
            $0.iterations > 0 && (1...99).contains($0.lowerHR)
                && (2...100).contains($0.upperHR) && $0.lowerHR < $0.upperHR
        }) else {
            return "Each block needs at least one repetition and heart-rate targets between 1% and 100%, with the lower target below the upper target."
        }
        return nil
    }

    func updateBlock(_ block: HeartRateInterval) {
        replaceBlocks(workout.blocks.map { $0.id == block.id ? block : $0 })
    }

    func addBlock() {
        replaceBlocks(workout.blocks + [HeartRateInterval(iterations: 3, lowerHR: 70, upperHR: 85)])
    }

    func removeBlock(id: UUID) {
        replaceBlocks(workout.blocks.filter { $0.id != id })
    }

    private func replaceBlocks(_ blocks: [HeartRateInterval]) {
        do {
            try workout.setBlocks(blocks)
        } catch {
            errorMessage = "A pyramid workout supports at most \(PyramidWorkout.maximumBlockCount) blocks."
        }
    }

    @discardableResult
    func saveWorkout(asNew: Bool = false) -> Bool {
        guard !trimmedName.isEmpty else {
            errorMessage = "Enter a workout name."
            return false
        }
        if let message = validationMessage {
            errorMessage = message
            return false
        }
        do {
            let createsCopy = asNew || workout.isBuiltIn
            let saved = try PyramidWorkout(
                id: createsCopy ? UUID() : workout.id,
                name: trimmedName,
                warmupSeconds: workout.warmupSeconds,
                blocks: workout.blocks,
                isFavorite: workout.isFavorite,
                createdAt: createsCopy ? Date() : workout.createdAt
            )
            guard storageManager.saveWorkout(saved) else {
                errorMessage = storageManager.lastError?.localizedDescription ?? "Unable to save workout. Please try again."
                return false
            }
            savedSnapshot = saved
            workout = saved
            saveName = saved.name
            errorMessage = nil
            saveCount += 1
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
