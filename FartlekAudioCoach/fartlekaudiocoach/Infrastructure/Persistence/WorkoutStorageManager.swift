import Combine
import Foundation

@MainActor
final class WorkoutStorageManager: ObservableObject {
    enum StorageError: LocalizedError {
        case loadFailed(Error)
        case saveFailed(Error)
        case deleteFailed(Error)
        case activeWorkout

        var errorDescription: String? {
            switch self {
            case .loadFailed(let error):
                return "Unable to load workouts: \(error.localizedDescription)"
            case .saveFailed(let error):
                return "Unable to save workout: \(error.localizedDescription)"
            case .deleteFailed(let error):
                return "Unable to delete workout: \(error.localizedDescription)"
            case .activeWorkout:
                return "This workout cannot be deleted because it is selected on the main screen or currently running. Select another workout, and stop this session if it is running, before deleting it."
            }
        }
    }

    @Published private(set) var workouts: [PyramidWorkout] = []
    @Published private(set) var lastError: StorageError?
    @Published private(set) var protectedWorkoutIDs = Set<UUID>()

    private let fileURL: URL?

    /// Pass a file URL to use an isolated location in tests or previews.
    /// Otherwise, workouts are stored in Documents/workouts.json.
    init(fileURL: URL? = nil) {
        self.fileURL = fileURL
        loadWorkouts()
    }

    /// On failure, retains the last successfully loaded state and publishes the error.
    @discardableResult
    func loadWorkouts() -> [PyramidWorkout] {
        do {
            workouts = try readWorkouts()
            lastError = nil
        } catch {
            lastError = .loadFailed(error)
        }
        return workouts
    }

    /// Inserts a new workout or replaces the workout with the same UUID.
    @discardableResult
    func saveWorkout(_ workout: PyramidWorkout) -> Bool {
        do {
            // Read first so an unreadable file is never replaced with an empty list.
            var updated = try readWorkouts()
            if let index = updated.firstIndex(where: { $0.id == workout.id }) {
                updated[index] = workout
            } else {
                updated.append(workout)
            }
            try writeWorkouts(updated)
            workouts = updated
            lastError = nil
            return true
        } catch {
            lastError = .saveFailed(error)
            return false
        }
    }

    func setProtectedWorkoutIDs(_ ids: Set<UUID>) {
        guard protectedWorkoutIDs != ids else { return }
        protectedWorkoutIDs = ids
        if case .activeWorkout? = lastError { lastError = nil }
    }

    func deletionRestriction(for id: UUID) -> String? {
        protectedWorkoutIDs.contains(id) ? StorageError.activeWorkout.errorDescription : nil
    }

    @discardableResult
    func deleteWorkout(id: UUID) -> Bool {
        guard !protectedWorkoutIDs.contains(id) else {
            lastError = .activeWorkout
            return false
        }
        do {
            var updated = try readWorkouts()
            updated.removeAll { $0.id == id }
            try writeWorkouts(updated)
            workouts = updated
            lastError = nil
            return true
        } catch {
            lastError = .deleteFailed(error)
            return false
        }
    }

    private func storageURL() throws -> URL {
        if let fileURL { return fileURL }
        let documents = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return documents.appendingPathComponent("workouts.json")
    }

    private func readWorkouts() throws -> [PyramidWorkout] {
        let url = try storageURL()
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain
            && error.code == NSFileReadNoSuchFileError {
            // A persisted [] means the user deleted everything; only a missing file is seeded.
            let templates = PyramidWorkout.standardTemplates
            try writeWorkouts(templates)
            return templates
        }
        return try JSONDecoder().decode([PyramidWorkout].self, from: data)
    }

    private func writeWorkouts(_ workouts: [PyramidWorkout]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(workouts)
        let url = try storageURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }
}
