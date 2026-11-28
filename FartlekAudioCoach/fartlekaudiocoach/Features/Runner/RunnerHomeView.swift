import SwiftUI
import UIKit

// MARK: - Heart Animation View using CABasicAnimation
struct HeartBeatView: UIViewRepresentable {
    let trigger: Int
    let tintColor: UIColor
    
    class HeartView: UIView {
        private let imageView = UIImageView()
        private var lastTrigger: Int?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            setupImageView()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setupImageView()
        }
        
        private func setupImageView() {
            let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .regular)
            imageView.image = UIImage(systemName: "heart.fill", withConfiguration: config)
            imageView.tintColor = .systemGray
            imageView.contentMode = .scaleAspectFit
            
            addSubview(imageView)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
                imageView.widthAnchor.constraint(equalTo: widthAnchor),
                imageView.heightAnchor.constraint(equalTo: heightAnchor)
            ])
        }
        
        func update(trigger: Int, tintColor: UIColor) {
            imageView.tintColor = tintColor
            guard lastTrigger != trigger else { return }
            lastTrigger = trigger
            let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
            pulseAnimation.toValue = NSNumber(value: 1.5)
            pulseAnimation.fromValue = NSNumber(value: 1.0)
            pulseAnimation.duration = 0.1
            pulseAnimation.repeatCount = 1
            pulseAnimation.autoreverses = true
            pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeIn)
            
            imageView.layer.add(pulseAnimation, forKey: "scale")
        }
    }
    
    func makeUIView(context: Context) -> HeartView {
        return HeartView()
    }
    
    func updateUIView(_ uiView: HeartView, context: Context) {
        uiView.update(trigger: trigger, tintColor: tintColor)
    }
}

// MARK: - Main View
struct RunnerHomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    let environment: AppEnvironment
    @StateObject private var model: RunnerViewModel
    @State private var showingSessions = false
    @State private var monitorDestination: MonitorDestination?
    @State private var showingSettings = false
    @State private var showingMenu = false
    @State private var showingStopConfirmation = false
    @State private var pendingMenuSelection: AppMenuSelection?
    @State private var menuDestination: AppMenuDestination?
    @State private var workoutToEdit: PyramidWorkout?
    @State private var legacySessionToEdit: SessionTemplate?
    @State private var sessionToSummarize: SessionTemplate?
    @State private var editorError: String?

    private enum MonitorDestination: Identifiable {
        case search
        case details(HeartRateDevice)

        var id: String {
            switch self {
            case .search: return "search"
            case .details(let device): return "details-\(device.id.uuidString)"
            }
        }
    }

    init(environment: AppEnvironment) {
        self.environment = environment
        _model = StateObject(wrappedValue: RunnerViewModel(environment: environment))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if model.settings.audioEnabled {
                        HStack {
                            Spacer()
                            Text(model.settings.heartRateSpeakIntervalSeconds == 0
                                 ? "Heart rate cue on every received sample"
                                 : "Next heart rate cue in: \(model.secondsUntilNextAnnouncement)s")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    model.announceWithTimeRemaining()
                                }
                            Spacer()
                        }
                        .padding(.top, -16)
                    }

                    connectionStatusSection
                    sessionPickerSection
                    heartRateDisplaySection
                    startSessionButtonSection
                    if model.isRunning {
                        cueMessageSection
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Fartlek")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        pendingMenuSelection = nil
                        showingMenu = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 20))
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("App menu")
                    .accessibilityIdentifier("appMenu")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        model.toggleAudio()
                    }) {
                        Image(systemName: model.settings.audioEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .task {
            await model.loadSettings()
        }
        .onAppear {
            model.updateHeartRateAvailability()
            environment.heartRateService.checkForExistingConnection()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.updateHeartRateAvailability()
                environment.heartRateService.checkForExistingConnection()
            }
        }
        .onReceive(environment.$selectedSession) { session in
            if let session { model.selectSession(session) }
        }
        .sheet(isPresented: $showingMenu, onDismiss: openSelectedMenuScreen) {
            AppMenuSheet { selection in
                pendingMenuSelection = selection
                showingMenu = false
            }
        }
        .sheet(isPresented: $showingSessions) {
            SessionPickerSheet(environment: environment, model: model)
        }
        .sheet(item: $sessionToSummarize) { session in
            SessionSummaryView(session: session)
        }
        .sheet(item: $workoutToEdit) { workout in
            NavigationStack {
                PyramidWorkoutEditorView(
                    workout: workout,
                    storageManager: environment.workoutStorageManager,
                    onUse: { updated in
                        model.selectSession(updated.asSessionTemplate())
                        workoutToEdit = nil
                    }
                )
            }
        }
        .sheet(item: $legacySessionToEdit) { session in
            NavigationStack {
                SessionDetailView(session: session, purchaseManager: environment.purchaseManager) { updated in
                    model.selectSession(updated)
                    legacySessionToEdit = nil
                }
                .environmentObject(environment)
            }
        }
        .sheet(item: $menuDestination) { destination in
            AppMenuView(destination: destination, purchaseManager: environment.purchaseManager, runnerModel: model)
        }
        .sheet(item: $monitorDestination) { destination in
            switch destination {
            case .search:
                HeartRateMonitorView(model: model)
            case .details(let device):
                HeartRateMonitorDetailView(device: device, model: model)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsHomeView(settings: Binding(
                get: { model.settings },
                set: { model.updateSettings($0) }
            ))
        }
        .alert("Could Not Open Workout", isPresented: Binding(
            get: { editorError != nil },
            set: { if !$0 { editorError = nil } }
        )) {
            Button("OK", role: .cancel) { editorError = nil }
        } message: {
            Text(editorError ?? "Please try again.")
        }
    }

    private var connectionStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monitor")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack {
                Button {
                    if case .connected(let device) = model.connectionState {
                        monitorDestination = .details(device)
                    }
                } label: {
                    HStack {
                        Image(systemName: connectionIcon)
                            .foregroundStyle(isConnected && !model.isHeartRateMissing ? .green : .orange)
                        Text(model.monitorStatus)
                            .font(.subheadline)
                            .accessibilityIdentifier("monitorConnectionStatus")
                        Spacer(minLength: 4)
                        if isConnected {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("View monitor details")
                .accessibilityIdentifier("viewConnectedMonitorDetails")
                .disabled(!isConnected)
                Button(action: { monitorDestination = .search }) {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.blue)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Search for heart rate monitors")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }

    private var sessionPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack {
                Button(action: openCurrentWorkoutDetails) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayedSession.name)
                                .font(.body.weight(.medium))
                                .lineLimit(1)
                            Text("Warmup: \(displayedSession.warmupSummary) · \(displayedSession.blocks.count) blocks")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: model.isRunning ? "info.circle" : "square.and.pencil")
                            .foregroundStyle(.blue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .accessibilityLabel(model.isRunning ? "View \(displayedSession.name) summary" : "Edit \(displayedSession.name)")
                .accessibilityHint(model.isRunning ? "View the running workout without changing it" : "View and edit the complete workout configuration")
                .accessibilityIdentifier(model.isRunning ? "viewRunningSessionSummary" : "editCurrentWorkout")
                Button(action: { showingSessions = true }) {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(model.isRunning ? Color.gray : Color.blue)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Select Session")
                .accessibilityHint(model.isRunning ? "Stop the session to select another workout" : "Choose a workout")
                .accessibilityIdentifier("selectSession")
                .disabled(model.isRunning)
            }
            .padding(.horizontal, 12)
            .frame(height: 72)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            if model.isRunning {
                Text("Tap the session for a summary. Stop to edit or select workouts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var heartRateDisplaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Heart rate")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Group {
                        if model.latestSample != nil && !model.isHeartRateMissing {
                            HeartBeatView(trigger: model.heartBeatTrigger,
                                          tintColor: currentHeartRateZone?.tintColor ?? .systemGray)
                        } else {
                            Image(systemName: "heart.slash")
                                .font(.system(size: 40))
                                .foregroundStyle(.orange)
                        }
                    }
                    .frame(width: 50, height: 50)
                    .accessibilityHidden(true)

                    Text(currentHeartRateZone?.shortTitle ?? "—")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(uiColor: currentHeartRateZone?.tintColor ?? .secondaryLabel))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .accessibilityIdentifier("currentHeartRateZone")
                }
                .frame(width: 64)
                .contentShape(Rectangle())
                .onTapGesture {
                    menuDestination = .heartRateZones
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(currentHeartRateZone.map { "Heart rate zone: \($0.title)" } ?? "Heart rate zone unavailable")
                .accessibilityHint("View heart rate zones and their training guidance")
                .accessibilityAddTraits(.isButton)
                
                VStack(spacing: 6) {
                    Text(displayValue)
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(model.isHeartRateMissing ? "No heart rate received" :
                         (model.latestSample == nil ? "Waiting for data" : displayUnit))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .onTapGesture {
                    model.toggleDisplayMode()
                }
                
                Button(action: { showingSettings = true }) {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.blue)
                        .font(.system(size: 24))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .frame(width: 50, height: 50)
            }
            .frame(height: 100)
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }

    private var startSessionButtonSection: some View {
        Button(action: {
            if model.isRunning {
                showingStopConfirmation = true
            } else {
                model.startSession()
            }
        }) {
            Text(model.isRunning ? "Stop Session" : "Start Session")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    model.isRunning ? Color.red :
                    (model.latestSample == nil || !isConnected ? Color.gray : Color.blue)
                )
                .cornerRadius(8)
        }
        .disabled(!model.isRunning && (model.latestSample == nil || !isConnected || model.isHeartRateMissing))
        .alert("Stop Session?", isPresented: $showingStopConfirmation) {
            Button("Stop Session", role: .destructive) {
                guard model.isRunning else { return }
                model.stopSession()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to stop this session?")
        }
        .onChange(of: model.isRunning) { _, isRunning in
            if !isRunning { showingStopConfirmation = false }
        }
    }

    private var cueMessageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current instruction")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(model.lastMessage.isEmpty ? "—" : model.lastMessage)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }

    private var isConnected: Bool {
        if case .connected = model.connectionState { return true }
        return false
    }

    private func openSelectedMenuScreen() {
        guard let selection = pendingMenuSelection else { return }
        pendingMenuSelection = nil
        menuDestination = selection.destination
    }

    private var displayedSession: SessionTemplate {
        model.runningSession ?? model.currentSession
    }

    private func openCurrentWorkoutDetails() {
        if model.isRunning {
            sessionToSummarize = model.runningSession
            return
        }
        let session = model.currentSession
        // Preserve legacy-only settings instead of silently dropping them.
        guard session.blocks.count <= PyramidWorkout.maximumBlockCount,
              session.blocks.allSatisfy({ $0.warmupRepetitions == 0 }),
              session.notes.isEmpty else {
            legacySessionToEdit = session
            return
        }
        let saved = environment.workoutStorageManager.workouts.first { $0.id == session.id }
        do {
            // Use the current runner configuration, not an older stored version.
            workoutToEdit = try PyramidWorkout(
                id: session.id,
                name: session.name,
                warmupSeconds: session.warmupDurationSeconds,
                blocks: session.blocks.map {
                    HeartRateInterval(id: $0.id, iterations: $0.repetitions,
                                      lowerHR: $0.lowerTargetPercent, upperHR: $0.upperTargetPercent)
                },
                isFavorite: saved?.isFavorite ?? false,
                createdAt: saved?.createdAt ?? Date(),
                isBuiltIn: session.isBuiltin
            )
        } catch {
            editorError = error.localizedDescription
        }
    }

    private var connectionIcon: String {
        if model.isHeartRateMissing { return "exclamationmark.triangle.fill" }
        return isConnected ? "checkmark.circle.fill" : "xmark.circle"
    }

    private var displayValue: String {
        guard let sample = model.latestSample else { return "--" }
        return model.settings.displayMode == .bpm ? "\(sample.bpm)" : "\(sample.percent)"
    }

    private var displayUnit: String {
        model.settings.displayMode == .bpm ? "BPM" : "% of max"
    }

    private var currentHeartRateZone: HeartRateZone? {
        guard !model.isHeartRateMissing, let sample = model.latestSample,
              model.settings.maxHeartRate > 0 else { return nil }
        let percent = HeartRateConverter.percent(from: sample.bpm, maxHeartRate: model.settings.maxHeartRate)
        return .zone(forPercent: percent)
    }
}

private struct SessionPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    let environment: AppEnvironment
    let model: RunnerViewModel
    @State private var sessions: [SessionTemplate] = []
    @State private var workoutToEdit: PyramidWorkout?
    @State private var creationError: String?
    @State private var deletionError: String?
    @ObservedObject var purchaseManager: PurchaseManager
    @ObservedObject private var workoutStorageManager: WorkoutStorageManager

    private var savedWorkouts: [PyramidWorkout] {
        workoutStorageManager.workouts.filter { !$0.isBuiltIn && !$0.isFavorite }
    }

    private var favoriteWorkouts: [PyramidWorkout] {
        workoutStorageManager.workouts.filter { !$0.isBuiltIn && $0.isFavorite }
    }

    init(environment: AppEnvironment, model: RunnerViewModel) {
        self.environment = environment
        self.model = model
        self._purchaseManager = ObservedObject(wrappedValue: environment.purchaseManager)
        self._workoutStorageManager = ObservedObject(wrappedValue: environment.workoutStorageManager)
    }

    var body: some View {
        NavigationStack {
            List {
                if let error = workoutStorageManager.lastError {
                    Section("Storage Error") {
                        Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                        Button("Try Again") { workoutStorageManager.loadWorkouts() }
                    }
                }
                if !favoriteWorkouts.isEmpty {
                    Section("Favorites") {
                        ForEach(favoriteWorkouts) { workout in
                            workoutRow(workout)
                        }
                        .onDelete { deleteWorkouts(at: $0, from: favoriteWorkouts) }
                    }
                }
                if !sessions.isEmpty {
                    Section("Previously Saved Sessions") {
                        ForEach(sessions) { session in
                            NavigationLink {
                                SessionDetailView(session: session, purchaseManager: purchaseManager) { editedSession in
                                    model.selectSession(editedSession)
                                    dismiss()
                                }
                                .environmentObject(environment)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(session.name)
                                            .font(.headline)
                                    }
                                    if !session.notes.isEmpty {
                                        Text(session.notes)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("Warmup: \(session.warmupSummary)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    ForEach(session.blocks) { block in
                                        Text("\(block.repetitions) repetitions · \(block.lowerTargetPercent)–\(block.upperTargetPercent)% of max")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
                Section("Other Workouts") {
                    if savedWorkouts.isEmpty {
                        Text(favoriteWorkouts.isEmpty ? "No saved workouts yet." : "Your saved workouts are in Favorites above.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(savedWorkouts) { workout in
                            workoutRow(workout)
                        }
                        .onDelete { deleteWorkouts(at: $0, from: savedWorkouts) }
                    }
                }
                Section("Templates") {
                    ForEach(PyramidWorkout.standardTemplates) { workout in
                        workoutRow(workout)
                    }
                }
                Section {
                    Button {
                        do {
                            workoutToEdit = try PyramidWorkout.newCustomPyramid()
                        } catch {
                            creationError = error.localizedDescription
                        }
                    } label: {
                        Label("Create New Custom Workout", systemImage: "plus.circle.fill")
                    }
                    .accessibilityIdentifier("createCustomPyramid")
                }
            }
            .navigationTitle("Select Session")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $workoutToEdit) { workout in
                NavigationStack {
                    PyramidWorkoutEditorView(
                        workout: workout,
                        storageManager: workoutStorageManager,
                        onUse: { workout in
                            model.selectSession(workout.asSessionTemplate())
                            workoutToEdit = nil
                            dismiss()
                        }
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
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
        .task {
            workoutStorageManager.loadWorkouts()
            sessions = ((try? await environment.sessionStore.loadSessions()) ?? []).filter { !$0.isBuiltin }
        }
    }

    private func workoutRow(_ workout: PyramidWorkout) -> some View {
        Button {
            workoutToEdit = workout
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.headline)
                    Text("\(workout.blocks.count) blocks · Warmup: \(workout.asSessionTemplate().warmupSummary)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(workout.blocks.map {
                        "\($0.iterations)× \($0.lowerHR)–\($0.upperHR)%"
                    }.joined(separator: " → "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if workout.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityLabel("Favorite")
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("workout-\(workout.id.uuidString)")
    }

    private func deleteWorkouts(at offsets: IndexSet, from workouts: [PyramidWorkout]) {
        let ids = offsets.compactMap { workouts.indices.contains($0) ? workouts[$0].id : nil }
        for id in ids {
            guard workoutStorageManager.deleteWorkout(id: id) else {
                deletionError = workoutStorageManager.lastError?.localizedDescription ?? "Unable to delete workout."
                break
            }
        }
    }
}
