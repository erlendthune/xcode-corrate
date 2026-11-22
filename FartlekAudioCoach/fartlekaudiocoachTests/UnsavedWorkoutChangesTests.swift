import Foundation
import Testing
@testable import fartlekaudiocoach

@MainActor
struct UnsavedWorkoutChangesTests {
    @Test func editsAndDiscardDoNotChangeStorage() throws {
        try withEditor { model, storage, file in
            let original = model.workout
            let data = try Data(contentsOf: file)
            #expect(!model.hasUnsavedChanges)
            model.saveName = "Renamed"
            model.workout.warmupSeconds += 60
            model.workout.isFavorite.toggle()
            var block = model.workout.blocks[0]
            block.iterations += 1
            model.updateBlock(block)
            #expect(model.hasUnsavedChanges)
            model.discardChanges()
            #expect(!model.hasUnsavedChanges)
            #expect(model.workout == original)
            #expect(model.saveName == original.name)
            #expect(try Data(contentsOf: file) == data)
            #expect(storage.workouts.contains(original))
        }
    }

    @Test func successfulSavesResetTheBaselineIncludingCopies() throws {
        try withEditor { model, _, _ in
            model.saveName = "Saved name"
            #expect(model.hasUnsavedChanges)
            #expect(model.saveWorkout())
            #expect(!model.hasUnsavedChanges)
            let originalID = model.workout.id
            model.saveName = "Copy"
            #expect(model.saveWorkout(asNew: true))
            #expect(model.workout.id != originalID)
            #expect(!model.hasUnsavedChanges)
            let copy = model.workout
            model.workout.warmupSeconds += 60
            model.discardChanges()
            #expect(model.workout == copy)
            #expect(model.saveName == "Copy")
        }
    }

    @Test func failedSaveKeepsChangesUnsaved() throws {
        try withEditor { model, _, file in
            model.saveName = "Unsaved name"
            try Data("invalid JSON".utf8).write(to: file)
            #expect(!model.saveWorkout())
            #expect(model.hasUnsavedChanges)
            #expect(model.saveName == "Unsaved name")
            #expect(model.errorMessage != nil)
        }
    }

    private func withEditor(_ check: (PyramidWorkoutEditorModel, WorkoutStorageManager, URL) throws -> Void) throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("workouts.json")
        let storage = WorkoutStorageManager(fileURL: file)
        let workout = try PyramidWorkout(name: "Draft", warmupSeconds: 600, blocks: [
            HeartRateInterval(iterations: 3, lowerHR: 70, upperHR: 85)
        ])
        #expect(storage.saveWorkout(workout))
        try check(PyramidWorkoutEditorModel(workout: workout, storageManager: storage), storage, file)
    }
}