import Foundation
import Testing
@testable import fartlekaudiocoach

@MainActor
struct WorkoutStorageManagerTests {
    private func withStorage(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory.appendingPathComponent("workouts.json"))
    }

    private func customWorkout() throws -> PyramidWorkout {
        try PyramidWorkout(
            name: "My Pyramid",
            warmupSeconds: 120,
            blocks: [HeartRateInterval(iterations: 4, lowerHR: 70, upperHR: 85)],
            isFavorite: true,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    @Test func firstLaunchSeedsAndPersistsTemplatesOnlyOnce() throws {
        try withStorage { url in
            let manager = WorkoutStorageManager(fileURL: url)
            #expect(manager.lastError == nil)
            #expect(manager.workouts == PyramidWorkout.standardTemplates)
            let saved = try Data(contentsOf: url)
            #expect(try JSONDecoder().decode([PyramidWorkout].self, from: saved) == manager.workouts)
            let reloaded = WorkoutStorageManager(fileURL: url)
            #expect(reloaded.loadWorkouts() == manager.workouts)
            #expect(try Data(contentsOf: url) == saved)
        }
    }

    @Test func savesAndUpdatesCustomWorkoutByID() throws {
        try withStorage { url in
            let manager = WorkoutStorageManager(fileURL: url)
            var custom = try customWorkout()
            #expect(manager.saveWorkout(custom))
            #expect(manager.workouts.count == PyramidWorkout.standardTemplates.count + 1)
            #expect(WorkoutStorageManager(fileURL: url).workouts.last == custom)

            custom.name = "Updated Pyramid"
            custom.isFavorite = false
            #expect(manager.saveWorkout(custom))
            let reloaded = WorkoutStorageManager(fileURL: url)
            #expect(reloaded.workouts.count == PyramidWorkout.standardTemplates.count + 1)
            #expect(reloaded.workouts.last == custom)
            #expect(reloaded.lastError == nil)
        }
    }

    @Test func deletesWorkoutsAndDoesNotRepopulateAnIntentionallyEmptyStore() throws {
        try withStorage { url in
            let manager = WorkoutStorageManager(fileURL: url)
            let custom = try customWorkout()
            #expect(manager.saveWorkout(custom))
            #expect(manager.deleteWorkout(id: custom.id))
            #expect(!WorkoutStorageManager(fileURL: url).workouts.contains { $0.id == custom.id })

            let ids = manager.workouts.map(\.id)
            for id in ids {
                #expect(manager.deleteWorkout(id: id))
            }
            #expect(manager.workouts.isEmpty)
            let reloaded = WorkoutStorageManager(fileURL: url)
            #expect(reloaded.workouts.isEmpty)
            #expect(reloaded.lastError == nil)
        }
    }

    @Test func unknownIDDeletionIsHarmless() throws {
        try withStorage { url in
            let manager = WorkoutStorageManager(fileURL: url)
            let original = manager.workouts
            #expect(manager.deleteWorkout(id: UUID()))
            #expect(manager.workouts == original)
        }
    }

    @Test func templatesAndCustomWorkoutsStaySeparateAfterReload() throws {
        try withStorage { url in
            let manager = WorkoutStorageManager(fileURL: url)
            let template = PyramidWorkout.classicPyramid
            let custom = try PyramidWorkout(
                name: template.name,
                warmupSeconds: template.warmupSeconds,
                blocks: template.blocks
            )
            #expect(manager.workouts.filter { !$0.isBuiltIn }.isEmpty)
            #expect(manager.saveWorkout(custom))
            let reloaded = WorkoutStorageManager(fileURL: url)
            #expect(reloaded.workouts.filter(\.isBuiltIn).count == PyramidWorkout.standardTemplates.count)
            #expect(reloaded.workouts.filter { !$0.isBuiltIn } == [custom])
            #expect(reloaded.deleteWorkout(id: custom.id))
            #expect(reloaded.workouts.filter { !$0.isBuiltIn }.isEmpty)
            #expect(reloaded.workouts.filter(\.isBuiltIn).count == PyramidWorkout.standardTemplates.count)
        }
    }

    @Test(arguments: [Data(), Data("invalid JSON".utf8)])
    func unreadableJSONIsNeverOverwritten(corruptData: Data) throws {
        try withStorage { url in
            try corruptData.write(to: url)
            let manager = WorkoutStorageManager(fileURL: url)
            #expect(manager.workouts.isEmpty)
            #expect(manager.lastError != nil)
            #expect(!manager.saveWorkout(try customWorkout()))
            #expect(!manager.deleteWorkout(id: UUID()))
            #expect(manager.lastError != nil)
            #expect(try Data(contentsOf: url) == corruptData)
        }
    }

    @Test func failedReloadRetainsStateAndSuccessfulReloadClearsError() throws {
        try withStorage { url in
            let manager = WorkoutStorageManager(fileURL: url)
            let original = manager.workouts
            let saved = try Data(contentsOf: url)
            try Data("broken".utf8).write(to: url)
            #expect(manager.loadWorkouts() == original)
            #expect(manager.lastError != nil)
            try saved.write(to: url)
            #expect(manager.loadWorkouts() == original)
            #expect(manager.lastError == nil)
        }
    }

    @Test func fileReadFailureIsReportedWithoutReplacingTheFile() throws {
        try withStorage { url in
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            let manager = WorkoutStorageManager(fileURL: url)
            #expect(manager.lastError != nil)
            #expect(!manager.saveWorkout(try customWorkout()))
            #expect(try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true)
        }
    }

    @Test func encodingFailurePreservesSavedAndPublishedWorkouts() throws {
        try withStorage { url in
            let manager = WorkoutStorageManager(fileURL: url)
            let original = manager.workouts
            let saved = try Data(contentsOf: url)
            var invalid = try customWorkout()
            invalid.createdAt = Date(timeIntervalSinceReferenceDate: .infinity)
            #expect(!manager.saveWorkout(invalid))
            #expect(manager.lastError != nil)
            #expect(manager.workouts == original)
            #expect(try Data(contentsOf: url) == saved)
            #expect(manager.saveWorkout(try customWorkout()))
            #expect(manager.lastError == nil)
        }
    }

    @Test func writeFailurePreservesSavedAndPublishedWorkouts() throws {
        try withStorage { url in
            let manager = WorkoutStorageManager(fileURL: url)
            let original = manager.workouts
            let saved = try Data(contentsOf: url)
            let directory = url.deletingLastPathComponent().path
            try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory)
            defer {
                try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory)
            }
            #expect(!manager.saveWorkout(try customWorkout()))
            #expect(manager.lastError != nil)
            #expect(!manager.deleteWorkout(id: original[0].id))
            #expect(manager.lastError != nil)
            #expect(manager.workouts == original)
            #expect(try Data(contentsOf: url) == saved)
        }
    }
}
