import SwiftUI
import UIKit

struct PyramidWorkoutEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: PyramidWorkoutEditorModel
    @ObservedObject private var storageManager: WorkoutStorageManager
    @State private var showingConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var showingUnsavedChanges = false
    @State private var invalidNumberFields = Set<String>()
    @FocusState private var isNameFocused: Bool
    var onSave: ((PyramidWorkout) -> Void)?
    var onUse: ((PyramidWorkout) -> Void)?

    init(workout: PyramidWorkout, storageManager: WorkoutStorageManager,
         onSave: ((PyramidWorkout) -> Void)? = nil,
         onUse: ((PyramidWorkout) -> Void)? = nil) {
        _model = StateObject(wrappedValue: PyramidWorkoutEditorModel(
            workout: workout, storageManager: storageManager
        ))
        _storageManager = ObservedObject(wrappedValue: storageManager)
        self.onSave = onSave
        self.onUse = onUse
    }

    var body: some View {
        Form {
            Section {
                TextField("Workout name", text: $model.saveName)
                    .font(.headline)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($isNameFocused)
                    .onSubmit { isNameFocused = false }
                    .accessibilityLabel("Workout name")
                    .accessibilityIdentifier("pyramidWorkoutName")
                if model.workout.isBuiltIn {
                    Text("Your changes will be saved as a custom workout. The built-in template stays unchanged.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                WorkoutNumberInput(title: "Warmup", unit: "min",
                                   value: $model.workout.warmupSeconds, range: 0...7200,
                                   step: 60, displayScale: 60,
                                   isValid: numberValidity("warmup"), identifier: "workoutWarmupMinutes")
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
                    saveWorkout()
                } label: {
                    Label("Save Workout", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.validationMessage != nil || model.trimmedName.isEmpty || !invalidNumberFields.isEmpty)
                .accessibilityIdentifier("savePyramidWorkout")
                Button {
                    saveWorkout(asNew: true)
                } label: {
                    Label("Save as New Workout", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(model.validationMessage != nil || model.trimmedName.isEmpty || !invalidNumberFields.isEmpty)
                .accessibilityIdentifier("saveAsNewWorkout")
            } footer: {
                Text("Save updates this workout. Save as New creates a separate copy and leaves the original unchanged.")
            }

            if model.canDeleteWorkout {
                Section {
                    Button(role: .destructive) {
                        dismissKeyboard()
                        if let message = storageManager.deletionRestriction(for: model.workout.id) {
                            model.errorMessage = message
                            return
                        }
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Workout", systemImage: "trash")
                    }
                    .accessibilityIdentifier("deletePyramidWorkout")
                }
            }
        }
        .navigationTitle("Editor")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .background {
            WorkoutDismissalGuard(hasUnsavedChanges: hasUnsavedChanges, onAttempt: requestClose)
                .frame(width: 0, height: 0)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done", action: requestClose)
                    .accessibilityIdentifier("closeWorkoutEditor")
            }
            if let onUse {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Use Workout") {
                        guard saveWorkout() else { return }
                        onUse(model.workout)
                    }
                    .disabled(model.validationMessage != nil || model.trimmedName.isEmpty || !invalidNumberFields.isEmpty)
                    .accessibilityIdentifier("usePyramidWorkout")
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { dismissKeyboard() }
            }
        }
        .alert("Save Changes?", isPresented: $showingUnsavedChanges) {
            Button("Save") {
                if saveWorkout() { dismiss() }
            }
            .disabled(model.validationMessage != nil || model.trimmedName.isEmpty || !invalidNumberFields.isEmpty)
            Button("Discard Changes", role: .destructive) {
                model.discardChanges()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This workout has unsaved changes. Save them before closing the editor?")
        }
        .confirmationDialog("Delete Workout?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Workout", role: .destructive) {
                if model.deleteWorkout() { dismiss() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete “\(model.workout.name)”? This cannot be undone.")
        }
        .alert("Workout Error", isPresented: Binding(
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

    private var hasUnsavedChanges: Bool {
        model.hasUnsavedChanges || !invalidNumberFields.isEmpty
    }

    private func requestClose() {
        let needsConfirmation = hasUnsavedChanges
        dismissKeyboard()
        if needsConfirmation { showingUnsavedChanges = true }
        else { dismiss() }
    }

    @discardableResult
    private func saveWorkout(asNew: Bool = false) -> Bool {
        guard invalidNumberFields.isEmpty else { return false }
        dismissKeyboard()
        guard model.saveWorkout(asNew: asNew) else { return false }
        onSave?(model.workout)
        return true
    }

    private func dismissKeyboard() {
        isNameFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func numberValidity(_ key: String) -> Binding<Bool> {
        Binding(
            get: { !invalidNumberFields.contains(key) },
            set: { valid in
                if valid { invalidNumberFields.remove(key) }
                else { invalidNumberFields.insert(key) }
            }
        )
    }

    private func blockSection(_ block: HeartRateInterval, index: Int) -> some View {
        let binding = Binding<HeartRateInterval>(
            get: { model.workout.blocks.first { $0.id == block.id } ?? block },
            set: { model.updateBlock($0) }
        )
        return Section("Block \(index + 1)") {
            WorkoutNumberInput(title: "Repetitions", unit: "",
                               value: binding.iterations, range: 1...100,
                               isValid: numberValidity("iterations-\(block.id)"),
                               identifier: "workoutRepetitions-\(block.id)")
            WorkoutNumberInput(title: "Lower target", unit: "%",
                               value: binding.lowerHR, range: 1...99,
                               isValid: numberValidity("lower-\(block.id)"),
                               identifier: "workoutLowerHR-\(block.id)")
            WorkoutNumberInput(title: "Upper target", unit: "%",
                               value: binding.upperHR, range: 2...100,
                               isValid: numberValidity("upper-\(block.id)"),
                               identifier: "workoutUpperHR-\(block.id)")
            Button("Remove Block", role: .destructive) {
                invalidNumberFields.remove("iterations-\(block.id)")
                invalidNumberFields.remove("lower-\(block.id)")
                invalidNumberFields.remove("upper-\(block.id)")
                model.removeBlock(id: block.id)
            }
        }
    }
}

/// Keep incomplete text (such as an empty field) separate from the saved value.
struct WorkoutNumberInput: View {
    let title: String
    let unit: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    var displayScale: Int = 1
    @Binding var isValid: Bool
    let identifier: String
    @State private var text = ""
    @State private var selection: TextSelection?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer(minLength: 8)
                TextField(title, text: $text, selection: $selection)
                    .keyboardType(displayScale == 1 ? .numberPad : .decimalPad)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                    .focused($isFocused)
                    .accessibilityLabel(unit.isEmpty ? title : "\(title) (\(unit))")
                    .accessibilityIdentifier(identifier)
                if !unit.isEmpty { Text(unit).foregroundStyle(.secondary) }
                Stepper(value: Binding(
                    get: { value },
                    set: {
                        value = $0
                        text = displayText($0)
                        isValid = true
                    }
                ), in: range, step: step) {
                    Text(title)
                }
                .labelsHidden()
                .fixedSize()
                .accessibilityLabel(title)
            }
            if !isValid {
                Text("Enter a number from \(displayText(range.lowerBound)) to \(displayText(range.upperBound)).")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .onAppear { text = displayText(value) }
        .onChange(of: text) { _, newText in
            guard let number = parsedValue(newText) else {
                isValid = false
                return
            }
            isValid = true
            if value != number { value = number }
        }
        .onChange(of: value) { _, newValue in
            if !isFocused { text = displayText(newValue) }
        }
        .onChange(of: isFocused) { _, focused in
            if focused {
                // Apply after the initial tap has positioned the system caret.
                // Subsequent taps still allow normal cursor movement while editing.
                DispatchQueue.main.async {
                    guard isFocused else { return }
                    selection = TextSelection(range: text.endIndex..<text.endIndex)
                }
            } else {
                selection = nil
                // Abandoned invalid input restores the last valid configuration.
                text = displayText(value)
                isValid = true
            }
        }
    }

    private func displayText(_ number: Int) -> String {
        if displayScale == 1 { return String(number) }
        return (Double(number) / Double(displayScale)).formatted(
            .number.grouping(.never).precision(.fractionLength(0...2))
        )
    }

    private func parsedValue(_ input: String) -> Int? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if displayScale == 1 {
            guard let number = Int(trimmed), range.contains(number) else { return nil }
            return number
        }
        let normalized = trimmed.replacingOccurrences(of: Locale.current.decimalSeparator ?? ".", with: ".")
        guard !normalized.isEmpty,
              normalized.allSatisfy({ $0.isNumber || $0 == "." }),
              let minutes = Double(normalized), minutes.isFinite else { return nil }
        let scaled = minutes * Double(displayScale)
        guard scaled >= Double(range.lowerBound), scaled <= Double(range.upperBound) else { return nil }
        return Int(scaled.rounded())
    }
}
