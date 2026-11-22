import Foundation
import Testing
@testable import fartlekaudiocoach

@MainActor
struct ActiveWorkoutDeletionTests {
    @Test func protectedWorkoutDeletionDoesNotChangePersistence() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("workouts.json")
        let storage = WorkoutStorageManager(fileURL: file)
        let workout = try PyramidWorkout(name: "Active workout", blocks: [
            HeartRateInterval(iterations: 3, lowerHR: 70, upperHR: 85)
        ])
        #expect(storage.saveWorkout(workout))
        storage.setProtectedWorkoutIDs([workout.id])
        let originalData = try Data(contentsOf: file)

        #expect(!storage.deleteWorkout(id: workout.id))
        #expect(storage.lastError?.localizedDescription.contains("cannot be deleted") == true)
        #expect(storage.workouts.contains { $0.id == workout.id })
        #expect(try Data(contentsOf: file) == originalData)
        let editor = PyramidWorkoutEditorModel(workout: workout, storageManager: storage)
        #expect(editor.canDeleteWorkout)
        #expect(!editor.deleteWorkout())
        #expect(editor.errorMessage?.contains("cannot be deleted") == true)

        storage.setProtectedWorkoutIDs([])
        #expect(editor.deleteWorkout())
        #expect(!storage.workouts.contains { $0.id == workout.id })
    }

    @Test func saveAsNewCopyIsNotProtectedByTheOriginalSelection() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let storage = WorkoutStorageManager(fileURL: folder.appendingPathComponent("workouts.json"))
        let original = try PyramidWorkout(name: "Original", blocks: [
            HeartRateInterval(iterations: 3, lowerHR: 70, upperHR: 85)
        ])
        #expect(storage.saveWorkout(original))
        storage.setProtectedWorkoutIDs([original.id])
        let editor = PyramidWorkoutEditorModel(workout: original, storageManager: storage)
        editor.saveName = "Copy"
        #expect(editor.saveWorkout(asNew: true))
        #expect(editor.workout.id != original.id)
        #expect(editor.deleteWorkout())
        #expect(!storage.deleteWorkout(id: original.id))
        #expect(storage.workouts.contains { $0.id == original.id })
    }
}