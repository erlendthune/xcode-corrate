import SwiftUI

struct PyramidWorkoutEditorView: View {
    @StateObject private var model: PyramidWorkoutEditorModel
    @State private var showingSaveName = false
    @State private var showingConfirmation = false
    var onSave: ((PyramidWorkout) -> Void)?
    var onUse: ((PyramidWorkout) -> Void)?

    init(workout: PyramidWorkout, storageManager: WorkoutStorageManager,
         onSave: ((PyramidWorkout) -> Void)? = nil,
         onUse: ((PyramidWorkout) -> Void)? = nil) {
        _model = StateObject(wrappedValue: PyramidWorkoutEditorModel(
            workout: workout, storageManager: storageManager
        ))
        self.onSave = onSave
        self.onUse = onUse
    }

    var body: some View {
        Form {
            Section {
                Text(model.workout.name)
                    .font(.headline)
                if model.workout.isBuiltIn {
                    Text("Your changes will be saved as a custom workout. The built-in template stays unchanged.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Stepper(value: $model.workout.warmupSeconds, in: 0...7200, step: 60) {
                    Text("Warmup: \(Double(model.workout.warmupSeconds) / 60, format: .number.precision(.fractionLength(0...2))) minutes")
                }
                Toggle("Favorite", isOn: $model.workout.isFavorite)
            }

            ForEach(Array(model.workout.blocks.enumerated()), id: \.element.id) { index, block in
                blockSection(block, index: index)
            }

            Section {
                Button {
                    model.addBlock()
                } label: {
                    Label("Add Block", systemImage: "plus.circle")
                }
                .disabled(model.workout.blocks.count >= PyramidWorkout.maximumBlockCount)
                .accessibilityIdentifier("addPyramidBlock")
                if let message = model.validationMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } footer: {
                Text("Use up to six blocks. Heart-rate targets are percentages of your maximum heart rate.")
            }

            Section {
                Button {
                    showingSaveName = true
                } label: {
                    Label("Save Workout", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.validationMessage != nil)
                .accessibilityIdentifier("savePyramidWorkout")
            }
        }
        .navigationTitle("Editor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onUse {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Use Workout") { onUse(model.workout) }
                        .disabled(model.validationMessage != nil)
                        .accessibilityIdentifier("usePyramidWorkout")
                }
            }
        }
        .alert("Save Workout", isPresented: $showingSaveName) {
            TextField("Workout name", text: $model.saveName)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("pyramidWorkoutName")
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if model.saveWorkout() { onSave?(model.workout) }
            }
            .disabled(model.trimmedName.isEmpty)
        } message: {
            Text("Give this workout a name so you can find it in My Saved Workouts.")
        }
        .alert("Could Not Save Workout", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "Please try again.")
        }
        .overlay(alignment: .bottom) {
            if showingConfirmation {
                Label("Workout saved", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom)
                    .accessibilityIdentifier("workoutSavedConfirmation")
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .sensoryFeedback(.success, trigger: model.saveCount)
        .task(id: model.saveCount) {
            guard model.saveCount > 0 else { return }
            withAnimation { showingConfirmation = true }
            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return
            }
            withAnimation { showingConfirmation = false }
        }
    }

    private func blockSection(_ block: HeartRateInterval, index: Int) -> some View {
        let binding = Binding<HeartRateInterval>(
            get: { model.workout.blocks.first { $0.id == block.id } ?? block },
            set: { model.updateBlock($0) }
        )
        return Section("Block \(index + 1)") {
            Stepper("Iterations: \(binding.wrappedValue.iterations)",
                    value: binding.iterations, in: 1...100)
            Stepper("Lower target: \(binding.wrappedValue.lowerHR)%",
                    value: binding.lowerHR, in: 1...99)
            Stepper("Upper target: \(binding.wrappedValue.upperHR)%",
                    value: binding.upperHR, in: 2...100)
            Button("Remove Block", role: .destructive) {
                model.removeBlock(id: block.id)
            }
        }
    }
}
