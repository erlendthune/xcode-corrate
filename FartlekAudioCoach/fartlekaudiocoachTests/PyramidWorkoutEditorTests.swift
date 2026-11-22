import Foundation
import Testing
@testable import fartlekaudiocoach

@MainActor
struct PyramidWorkoutEditorTests {
    @Test func pyramidSelectionPreservesRunnerConfiguration() throws {
        var workout = try PyramidWorkout.newCustomPyramid()
        workout.warmupSeconds = 95
        let session = workout.asSessionTemplate()
        #expect(session.id == workout.id)
        #expect(session.name == workout.name)
        #expect(session.warmupDurationSeconds == 95)
        #expect(session.warmupSummary == "1 min 35 sec")
        #expect(!session.isPremium)
        #expect(session.blocks.map(\.id) == workout.blocks.map(\.id))
        #expect(session.blocks.map(\.repetitions) == workout.blocks.map(\.iterations))
        #expect(session.blocks.map(\.lowerTargetPercent) == workout.blocks.map(\.lowerHR))
        #expect(session.blocks.map(\.upperTargetPercent) == workout.blocks.map(\.upperHR))
        #expect(try JSONDecoder().decode(SessionTemplate.self, from: JSONEncoder().encode(session)) == session)
    }

    @Test func selectedPyramidUsesExactWarmupSeconds() throws {
        var workout = try PyramidWorkout.newCustomPyramid()
        workout.warmupSeconds = 95
        let engine = DefaultSessionEngine()
        engine.reset(session: workout.asSessionTemplate())
        let start = Date()
        var settings = AppSettings.default
        settings.displayMode = .percent
        func consume(after seconds: TimeInterval) -> [SessionCue] {
            let now = start.addingTimeInterval(seconds)
            return engine.consume(sample: HeartRateSample(bpm: 100, percent: 60, timestamp: now),
                                  settings: settings, now: now)
        }
        #expect(consume(after: 0) == [.warmupStarted(minutes: 2)])
        #expect(consume(after: 94) == [.warmupMinutesRemaining(1)])
        #expect(consume(after: 95).isEmpty)
        #expect(consume(after: 96) == [.speedUp(target: 85, repetition: 1, total: 3)])
    }

    @Test func onlySavedCustomWorkoutsCanBeDeleted() throws {
        try withStorage { storage, url in
            let template = PyramidWorkoutEditorModel(workout: .flatFartlek, storageManager: storage)
            #expect(!template.canDeleteWorkout)
            #expect(!template.deleteWorkout())
            let draft = PyramidWorkoutEditorModel(workout: try .newCustomPyramid(), storageManager: storage)
            #expect(!draft.canDeleteWorkout)
            #expect(!draft.deleteWorkout())
            #expect(draft.saveWorkout())
            #expect(draft.canDeleteWorkout)
            let id = draft.workout.id
            #expect(draft.deleteWorkout())
            #expect(!draft.canDeleteWorkout)
            #expect(!WorkoutStorageManager(fileURL: url).workouts.contains { $0.id == id })
            #expect(storage.workouts == PyramidWorkout.standardTemplates)
        }
    }

    @Test func deletingFavoriteCopyLeavesOriginalUntouched() throws {
        try withStorage { storage, url in
            let original = try PyramidWorkout.newCustomPyramid()
            #expect(storage.saveWorkout(original))
            let model = PyramidWorkoutEditorModel(workout: original, storageManager: storage)
            model.saveName = "Favorite copy"
            model.workout.isFavorite = true
            #expect(model.saveWorkout(asNew: true))
            let copyID = model.workout.id
            #expect(model.deleteWorkout())
            let saved = WorkoutStorageManager(fileURL: url).workouts
            #expect(saved.first { $0.id == original.id } == original)
            #expect(!saved.contains { $0.id == copyID })
            #expect(!saved.contains { $0.isFavorite })
        }
    }

    @Test func failedDeletionRetainsWorkoutAndCanBeRetried() throws {
        try withStorage { storage, url in
            let workout = try PyramidWorkout.newCustomPyramid()
            #expect(storage.saveWorkout(workout))
            let model = PyramidWorkoutEditorModel(workout: workout, storageManager: storage)
            let saved = try Data(contentsOf: url)
            let corrupt = Data("corrupt JSON".utf8)
            try corrupt.write(to: url)
            #expect(!model.deleteWorkout())
            #expect(model.errorMessage != nil)
            #expect(model.workout == workout)
            #expect(model.canDeleteWorkout)
            #expect(try Data(contentsOf: url) == corrupt)
            try saved.write(to: url)
            #expect(model.deleteWorkout())
            #expect(model.errorMessage == nil)
            #expect(!WorkoutStorageManager(fileURL: url).workouts.contains { $0.id == workout.id })
        }
    }

    private func withStorage(_ body: (WorkoutStorageManager, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("workouts.json")
        try body(WorkoutStorageManager(fileURL: url), url)
    }

    @Test func newDraftIsOnlyPersistedAfterNamedSave() throws {
        try withStorage { storage, url in
            let draft = try PyramidWorkout.newCustomPyramid()
            let model = PyramidWorkoutEditorModel(workout: draft, storageManager: storage)
            model.workout.warmupSeconds = 95
            model.workout.isFavorite = true
            model.saveName = "  My Morning Pyramid \n"
            #expect(storage.workouts.count == PyramidWorkout.standardTemplates.count)
            #expect(model.saveWorkout())
            let saved = try #require(WorkoutStorageManager(fileURL: url).workouts.last)
            #expect(saved.id == draft.id)
            #expect(saved.name == "My Morning Pyramid")
            #expect(saved.warmupSeconds == 95)
            #expect(saved.blocks == draft.blocks)
            #expect(saved.isFavorite)
            #expect(!saved.isBuiltIn)
            #expect(model.saveCount == 1)
            #expect(model.errorMessage == nil)
        }
    }

    @Test func editingExistingWorkoutPreservesIdentityAndCreationDate() throws {
        try withStorage { storage, url in
            let original = try PyramidWorkout.newCustomPyramid()
            #expect(storage.saveWorkout(original))
            let model = PyramidWorkoutEditorModel(workout: original, storageManager: storage)
            model.saveName = "Renamed Workout"
            var block = original.blocks[0]
            block.iterations = 7
            model.updateBlock(block)
            #expect(model.saveWorkout())
            #expect(model.saveWorkout())
            let customs = WorkoutStorageManager(fileURL: url).workouts.filter { !$0.isBuiltIn }
            #expect(customs.count == 1)
            #expect(customs[0].id == original.id)
            #expect(customs[0].createdAt == original.createdAt)
            #expect(customs[0].name == "Renamed Workout")
            #expect(customs[0].blocks[0].iterations == 7)
            #expect(model.saveCount == 2)
        }
    }

    @Test func saveAsNewPreservesOriginalAndSubsequentSavesUpdateCopy() throws {
        try withStorage { storage, url in
            var original = try PyramidWorkout.newCustomPyramid()
            original.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
            #expect(storage.saveWorkout(original))
            let model = PyramidWorkoutEditorModel(workout: original, storageManager: storage)
            model.saveName = "New variation"
            model.workout.warmupSeconds = 120
            model.workout.isFavorite = true
            #expect(model.saveWorkout(asNew: true))
            let copy = model.workout
            #expect(copy.id != original.id)
            #expect(copy.createdAt > original.createdAt)
            #expect(copy.blocks == original.blocks)
            #expect(copy.isFavorite)
            #expect(!copy.isBuiltIn)
            model.saveName = "Updated variation"
            #expect(model.saveWorkout())
            let customs = WorkoutStorageManager(fileURL: url).workouts.filter { !$0.isBuiltIn }
            #expect(customs.count == 2)
            #expect(customs.first { $0.id == original.id } == original)
            let updated = try #require(customs.first { $0.id == copy.id })
            #expect(updated.name == "Updated variation")
            #expect(updated.warmupSeconds == 120)
            #expect(updated.createdAt == copy.createdAt)
        }
    }

    @Test func failedSaveAsNewKeepsOriginalIdentityAndDraft() throws {
        try withStorage { storage, url in
            let original = try PyramidWorkout.newCustomPyramid()
            #expect(storage.saveWorkout(original))
            let data = try Data(contentsOf: url)
            let model = PyramidWorkoutEditorModel(workout: original, storageManager: storage)
            model.saveName = "Unsaved copy"
            try Data("corrupt JSON".utf8).write(to: url)
            #expect(!model.saveWorkout(asNew: true))
            #expect(model.workout == original)
            #expect(model.saveName == "Unsaved copy")
            #expect(model.saveCount == 0)
            try data.write(to: url)
            #expect(model.saveWorkout(asNew: true))
            #expect(model.workout.id != original.id)
            #expect(WorkoutStorageManager(fileURL: url).workouts.first { $0.id == original.id } == original)
        }
    }

    @Test(arguments: PyramidWorkout.standardTemplates)
    func savingBuiltinCreatesOneCustomCopyAndLeavesTemplateUntouched(template: PyramidWorkout) throws {
        try withStorage { storage, url in
            let model = PyramidWorkoutEditorModel(workout: template, storageManager: storage)
            model.saveName = "My Classic"
            model.workout.warmupSeconds = 180
            #expect(model.saveWorkout())
            let customID = model.workout.id
            #expect(customID != template.id)
            #expect(!model.workout.isBuiltIn)
            model.saveName = "My Classic Updated"
            #expect(model.saveWorkout())
            let saved = WorkoutStorageManager(fileURL: url).workouts
            #expect(saved.count == PyramidWorkout.standardTemplates.count + 1)
            #expect(saved.first { $0.id == template.id } == template)
            #expect(saved.last?.id == customID)
            #expect(saved.last?.name == "My Classic Updated")
        }
    }

    @Test func unsavedChangesNeverModifyStoredWorkout() throws {
        try withStorage { storage, url in
            let draft = try PyramidWorkout.newCustomPyramid()
            #expect(storage.saveWorkout(draft))
            let original = try Data(contentsOf: url)
            let model = PyramidWorkoutEditorModel(workout: draft, storageManager: storage)
            model.workout.warmupSeconds = 0
            model.saveName = "Unsaved"
            model.removeBlock(id: draft.blocks[0].id)
            #expect(try Data(contentsOf: url) == original)
            #expect(model.saveCount == 0)
        }
    }

    @Test(arguments: ["", "  \n "])
    func emptyNamesAreRejected(name: String) throws {
        try withStorage { storage, _ in
            let model = PyramidWorkoutEditorModel(workout: try .newCustomPyramid(), storageManager: storage)
            model.saveName = name
            #expect(!model.saveWorkout())
            #expect(model.errorMessage != nil)
            #expect(model.saveCount == 0)
            #expect(storage.workouts.count == PyramidWorkout.standardTemplates.count)
        }
    }

    @Test func invalidIntervalsAndEmptyWorkoutsCannotBeSaved() throws {
        try withStorage { storage, _ in
            let empty = try PyramidWorkout(name: "Empty", blocks: [])
            let model = PyramidWorkoutEditorModel(workout: empty, storageManager: storage)
            #expect(!model.saveWorkout())
            model.addBlock()
            var invalid = model.workout.blocks[0]
            invalid.lowerHR = invalid.upperHR
            model.updateBlock(invalid)
            #expect(!model.saveWorkout())
            #expect(model.saveCount == 0)
            #expect(storage.workouts.count == PyramidWorkout.standardTemplates.count)
        }
    }

    @Test func addingBlocksEnforcesSixBlockMaximum() throws {
        try withStorage { storage, _ in
            let model = PyramidWorkoutEditorModel(workout: try .newCustomPyramid(), storageManager: storage)
            model.addBlock()
            #expect(model.workout.blocks.count == 6)
            #expect(model.errorMessage != nil)
            model.removeBlock(id: model.workout.blocks[0].id)
            model.addBlock()
            #expect(model.workout.blocks.count == 6)
        }
    }

    @Test func failedSaveRetainsDraftAndCanBeRetried() throws {
        try withStorage { storage, url in
            let draft = try PyramidWorkout.newCustomPyramid()
            let model = PyramidWorkoutEditorModel(workout: draft, storageManager: storage)
            let original = try Data(contentsOf: url)
            let corrupt = Data("corrupt JSON".utf8)
            try corrupt.write(to: url)
            model.saveName = "Retry Me"
            #expect(!model.saveWorkout())
            #expect(model.errorMessage != nil)
            #expect(model.workout == draft)
            #expect(model.saveName == "Retry Me")
            #expect(model.saveCount == 0)
            #expect(try Data(contentsOf: url) == corrupt)
            try original.write(to: url)
            #expect(model.saveWorkout())
            #expect(model.workout.id == draft.id)
            #expect(model.workout.name == "Retry Me")
            #expect(model.errorMessage == nil)
            #expect(model.saveCount == 1)
        }
    }
}
