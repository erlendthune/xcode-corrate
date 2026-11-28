import SwiftUI

/// Embed in a NavigationStack. By default selections open the editor; callbacks can override this.
struct WorkoutTemplateSelectionView: View {
    @ObservedObject var storageManager: WorkoutStorageManager
    var onSelect: ((PyramidWorkout) -> Void)?
    var onCreate: ((PyramidWorkout) -> Void)?
    var onUse: ((PyramidWorkout) -> Void)?

    @State private var selectedWorkoutID: UUID?
    @State private var creationError: String?
    @State private var deletionError: String?
    @State private var workoutToEdit: PyramidWorkout?

    private var savedWorkouts: [PyramidWorkout] {
        storageManager.workouts.filter { !$0.isBuiltIn && !$0.isFavorite }
    }

    private var favoriteWorkouts: [PyramidWorkout] {
        storageManager.workouts.filter { !$0.isBuiltIn && $0.isFavorite }
    }

    var body: some View {
        List {
            if let error = storageManager.lastError {
                Section("Storage Error") {
                    Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("workoutStorageError")
                    Button("Try Again") {
                        storageManager.loadWorkouts()
                    }
                }
            }

            if !favoriteWorkouts.isEmpty {
                Section("Favorites") {
                    ForEach(favoriteWorkouts) { workout in
                        selectionRow(workout)
                    }
                    .onDelete { deleteWorkouts(at: $0, from: favoriteWorkouts) }
                }
            }

            Section {
                if savedWorkouts.isEmpty {
                    Text(favoriteWorkouts.isEmpty
                         ? "No saved workouts yet. Create a custom workout to get started."
                         : "Your saved workouts are in Favorites above.")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("emptySavedWorkouts")
                } else {
                    ForEach(savedWorkouts) { workout in
                        selectionRow(workout)
                    }
                    .onDelete { deleteWorkouts(at: $0, from: savedWorkouts) }
                }
            } header: {
                Text("Other Workouts")
            } footer: {
                Text("Swipe left on a saved workout to delete it.")
            }

            Section("Templates") {
                // Templates remain available even when the saved collection is empty or unreadable.
                ForEach(PyramidWorkout.standardTemplates) { workout in
                    selectionRow(workout)
                }
            }

            Section {
                Button {
                    do {
                        let draft = try PyramidWorkout.newCustomPyramid()
                        if let action = onCreate ?? onSelect {
                            action(draft)
                        } else {
                            workoutToEdit = draft
                        }
                    } catch {
                        creationError = error.localizedDescription
                    }
                } label: {
                    Label("Create New Custom Workout", systemImage: "plus.circle.fill")
                }
                .accessibilityIdentifier("createCustomPyramid")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Workouts")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $workoutToEdit) { workout in
            NavigationStack {
                PyramidWorkoutEditorView(workout: workout, storageManager: storageManager, onUse: editorOnUse)
            }
        }
        .task {
            storageManager.loadWorkouts()
        }
        .alert("Could Not Create Workout", isPresented: Binding(
            get: { creationError != nil },
            set: { if !$0 { creationError = nil } }
        )) {
            Button("OK", role: .cancel) { creationError = nil }
        } message: {
            Text(creationError ?? "Please try again.")
        }
        .alert("Cannot Delete Workout", isPresented: Binding(
            get: { deletionError != nil },
            set: { if !$0 { deletionError = nil } }
        )) {
            Button("OK", role: .cancel) { deletionError = nil }
        } message: {
            Text(deletionError ?? "Please try again.")
        }
    }

    private var editorOnUse: ((PyramidWorkout) -> Void)? {
        guard let onUse else { return nil }
        return { workout in
            selectedWorkoutID = workout.id
            onUse(workout)
            workoutToEdit = nil
        }
    }

    private func selectionRow(_ workout: PyramidWorkout) -> some View {
        Button {
            selectedWorkoutID = workout.id
            if let onSelect {
                onSelect(workout)
            } else {
                workoutToEdit = workout
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(workout.name)
                        .font(.headline)
                    Text("\(workout.blocks.count) \(workout.blocks.count == 1 ? "block" : "blocks") · Warmup: \(Double(workout.warmupSeconds) / 60, format: .number.precision(.fractionLength(0...2))) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(workout.blocks.isEmpty ? "No intervals configured" : workout.blocks.map {
                        "\($0.iterations)× \($0.lowerHR)–\($0.upperHR)%"
                    }.joined(separator: " → "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Heart-rate targets are % of maximum")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if workout.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityLabel("Favorite")
                }
                if selectedWorkoutID == workout.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Selected")
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("workout-\(workout.id.uuidString)")
    }

    private func deleteWorkouts(at offsets: IndexSet, from workouts: [PyramidWorkout]) {
        // Resolve IDs before mutating storage; offsets refer to the filtered custom section.
        let ids = offsets.compactMap { workouts.indices.contains($0) ? workouts[$0].id : nil }
        for id in ids {
            guard storageManager.deleteWorkout(id: id) else {
                deletionError = storageManager.lastError?.localizedDescription ?? "Unable to delete workout."
                break
            }
            if selectedWorkoutID == id { selectedWorkoutID = nil }
        }
    }
}
