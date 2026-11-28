import Combine
import Foundation
import UIKit

@MainActor
final class RunnerViewModel: ObservableObject {
    private static let heartRateDisplayTimeout: TimeInterval = 3
    private static let heartRateWarningInterval: TimeInterval = 9.5
    private static let supportReminderInterval: TimeInterval = 10 * 60
    private static let supportReminder = "If you enjoy using the app; please buy it so my wife can buy herself new shoes."

    @Published private(set) var connectionState: HeartRateConnectionState = .disconnected
    @Published private(set) var devices: [HeartRateDevice] = []
    @Published private(set) var deviceSpecifications: [UUID: HeartRateDeviceSpecifications] = [:]
    @Published private(set) var latestSample: HeartRateSample?
    @Published private(set) var isHeartRateMissing = false
    @Published private(set) var cues: [SessionCue] = []
    @Published private(set) var lastMessage: String = ""
    @Published private(set) var isRunning = false
    @Published private(set) var runningSession: SessionTemplate?
    @Published private(set) var settings = AppSettings.default
    @Published var currentSession: SessionTemplate {
        didSet { updateWorkoutDeletionProtection() }
    }
    @Published private(set) var heartBeatTrigger = 0  // Incremented to trigger animation
    @Published private(set) var secondsUntilNextAnnouncement: Int = 0

    let sessionEngine: SessionEngine
    private let heartRateService: HeartRateService
    private let settingsStore: SettingsStore
    private let sessionStore: SessionStore
    private let audioCoach: AudioCoach
    private let workoutStorageManager: WorkoutStorageManager?
    private var lastDisplayedCue: SessionCue?
    private let announcementClock: () -> TimeInterval
    private let hasPurchased: () -> Bool
    private var lastSupportReminderTime: TimeInterval?
    private var lastHeartRateAnnounceTime: TimeInterval?
    private var settingsSaveTask: Task<Void, Never>?
    private var heartBeatTimer: Timer?
    private var heartRateLossWarningTimer: Timer?
    private var countdownTimer: Timer?
    private var previousHeartRate: Int = 0
    private var hasAnnouncedFirstSample = false
    private var lastBeatTime: Date?
    private var lastWarningTime: Double = 0
    private var lifecycleObservers = Set<AnyCancellable>()
    private var heartRateWatchdogTask: UIBackgroundTaskIdentifier = .invalid
    private var heartRateWatchdogRequestID: UUID?

    var availableDevices: [HeartRateDevice] {
        guard case .connected(let connectedDevice) = connectionState else { return devices }
        // A connected monitor need not advertise or appear in the latest scan.
        return [connectedDevice] + devices.filter { $0.id != connectedDevice.id }
    }

    var monitorStatus: String {
        switch connectionState {
        case .disconnected: return "No monitor connected"
        case .scanning: return "Searching..."
        case .connecting(let device): return "Connecting to \(device.name)..."
        case .connected(let device):
            return isHeartRateMissing
                ? "Connected to \(device.name) — no heart rate received"
                : "Connected to \(device.name)"
        }
    }

    convenience init(environment: AppEnvironment) {
        self.init(heartRateService: environment.heartRateService,
                  settingsStore: environment.settingsStore,
                  sessionStore: environment.sessionStore,
                  sessionEngine: environment.sessionEngine,
                  audioCoach: environment.audioCoach,
                  workoutStorageManager: environment.workoutStorageManager,
                  hasPurchased: { environment.purchaseManager.isPremium })
    }

    init(heartRateService: HeartRateService, settingsStore: SettingsStore,
         sessionStore: SessionStore, sessionEngine: SessionEngine, audioCoach: AudioCoach,
         announcementClock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         workoutStorageManager: WorkoutStorageManager? = nil,
         hasPurchased: @escaping () -> Bool = { false }) {
        self.sessionEngine = sessionEngine
        self.heartRateService = heartRateService
        self.settingsStore = settingsStore
        self.sessionStore = sessionStore
        self.audioCoach = audioCoach
        self.workoutStorageManager = workoutStorageManager
        self.announcementClock = announcementClock
        self.hasPurchased = hasPurchased
        currentSession = PyramidWorkout.flatFartlek.asSessionTemplate()
        updateWorkoutDeletionProtection()

        heartRateService.onConnectionStateChanged = { [weak self] state in
            self?.receive(connectionState: state)
        }
        heartRateService.onSample = { [weak self] sample in
            self?.receive(sample: sample)
        }
        heartRateService.onDevicesChanged = { [weak self] devices in
            self?.devices = devices
        }
        heartRateService.onSpecificationsChanged = { [weak self] id, specifications in
            self?.deviceSpecifications[id] = specifications
        }
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    self?.beginHeartRateWatchdogTask()
                }
            }
            .store(in: &lifecycleObservers)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    self?.endHeartRateWatchdogTask()
                    self?.updateHeartRateAvailability()
                }
            }
            .store(in: &lifecycleObservers)
    }

    private func receive(connectionState state: HeartRateConnectionState) {
        connectionState = state
        switch state {
        case .disconnected:
            latestSample = nil
            isHeartRateMissing = lastBeatTime != nil
            hasAnnouncedFirstSample = false
            stopHeartBeatTimer()
            beginHeartRateWatchdogTask()
        case .connecting:
            latestSample = nil
            hasAnnouncedFirstSample = false
            // Reconnecting is not recovery: only a fresh sample clears the warning.
            if lastBeatTime == nil {
                lastBeatTime = Date()
                lastWarningTime = 0
            }
            stopHeartBeatTimer()
            startHeartRateLossWarningTimer()
        case .connected:
            if lastBeatTime == nil { lastBeatTime = Date() }
            startHeartRateLossWarningTimer()
        case .scanning:
            break
        }
    }

    func loadSettings() async {
        NSLog("🟢 RunnerViewModel: loadSettings() called")
        settings = await settingsStore.loadSettings()
        // Early Bluetooth samples use the muted default. After loading preferences,
        // only a fresh sample may announce, using the user's actual audio setting.
        hasAnnouncedFirstSample = false
        // Built-in starting points come from the modern workout templates, not
        // legacy sessions with obsolete editor-only fields.
        if !isRunning, !currentSession.isBuiltin,
           let sessions = try? await sessionStore.loadSessions(),
           let savedSession = sessions.first(where: {
               !$0.isBuiltin && $0.id == currentSession.id
           }) {
            currentSession = savedSession
        }
        resetAnnouncementSchedule()
        
        // First, check for existing connections (OS-level connected peripherals)
        heartRateService.checkForExistingConnection()
        
        // Give a small delay for the connection state to update
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // If still disconnected after checking existing connections, try to reconnect to last used device
        if case .disconnected = connectionState {
            if let lastDevice = await settingsStore.loadLastConnectedDevice() {
                NSLog("🟢 RunnerViewModel: Found saved device: \(lastDevice.name) - \(lastDevice.id)")
                // Try to reconnect to the last used device
                heartRateService.connect(to: lastDevice)
            } else {
                NSLog("🟢 RunnerViewModel: No saved device found, starting scan...")
                // No saved device, start a scan to discover devices
                heartRateService.startScan()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    NSLog("🟢 RunnerViewModel: 3-second scan timeout, stopping scan")
                    self?.heartRateService.stopScan()
                }
            }
        } else {
            NSLog("🟢 RunnerViewModel: Already connected after checking existing connections")
        }
    }

    func connect() {
        heartRateService.startScan()
    }

    func stopScan() {
        heartRateService.stopScan()
    }

    func disconnect() {
        lastBeatTime = nil
        endHeartRateWatchdogTask()
        heartRateService.disconnect()
        latestSample = nil
        isHeartRateMissing = false
        stopHeartBeatTimer()
        hasAnnouncedFirstSample = false
        lastWarningTime = 0
        stopHeartRateLossWarningTimer()
        stopCountdownTimer()
    }

    func connect(to device: HeartRateDevice) {
        if case .connected(let connected) = connectionState, connected.id == device.id {
            return
        }
        heartRateService.connect(to: device)
    }

    func startSession() {
        guard !isRunning else { return }
        let snapshot = currentSession
        runningSession = snapshot
        sessionEngine.reset(session: snapshot)
        updateWorkoutDeletionProtection()
        cues = []
        lastMessage = ""
        lastDisplayedCue = nil
        isRunning = true
        lastWarningTime = 0
        startHeartRateLossWarningTimer()
        audioCoach.activate()
        audioCoach.speak("Session started.", settings: settings)
    }

    func stopSession() {
        isRunning = false
        runningSession = nil
        updateWorkoutDeletionProtection()
        cues = []
        lastMessage = ""
        lastDisplayedCue = nil
        audioCoach.speak("Fartlek stopped.", settings: settings)
        audioCoach.deactivate()
        stopHeartBeatTimer()
    }

    func selectSession(_ session: SessionTemplate) {
        currentSession = session
    }

    private func updateWorkoutDeletionProtection() {
        var ids: Set<UUID> = [currentSession.id]
        if let runningSession { ids.insert(runningSession.id) }
        workoutStorageManager?.setProtectedWorkoutIDs(ids)
    }

    func updateSettings(_ updated: AppSettings) {
        let intervalChanged = settings.heartRateSpeakIntervalSeconds != updated.heartRateSpeakIntervalSeconds
        let cueFormatChanged = settings.displayMode != updated.displayMode || settings.maxHeartRate != updated.maxHeartRate
        let audioWasEnabled = settings.audioEnabled
        settings = updated
        if cueFormatChanged, let lastDisplayedCue {
            lastMessage = message(for: lastDisplayedCue)
        }
        if audioWasEnabled && !updated.audioEnabled {
            lastSupportReminderTime = nil
            audioCoach.stop()
            endHeartRateWatchdogTask()
        } else if !audioWasEnabled && updated.audioEnabled {
            beginHeartRateWatchdogTask()
        }
        if intervalChanged { resetAnnouncementSchedule() }
        // Keep rapid edits in order so an older save cannot overwrite the latest one.
        let previousSave = settingsSaveTask
        settingsSaveTask = Task { [settingsStore] in
            await previousSave?.value
            await settingsStore.saveSettings(updated)
        }
    }

    func toggleAudio() {
        var newSettings = settings
        let wasAudioDisabled = !settings.audioEnabled
        newSettings.audioEnabled.toggle()
        updateSettings(newSettings)
        
        // Announce heart rate immediately if audio was just enabled
        if wasAudioDisabled && newSettings.audioEnabled {
            announceHeartRateOnly()
        }
    }
    
    func toggleDisplayMode() {
        var newSettings = settings
        newSettings.displayMode = newSettings.displayMode == .bpm ? .percent : .bpm
        updateSettings(newSettings)
    }
    
    func announceWithTimeRemaining() {
        updateHeartRateAvailability()
        guard settings.audioEnabled, !isHeartRateMissing, let sample = latestSample else { return }
        
        let display = settings.displayMode == .bpm ? sample.bpm : sample.percent
        
        let secondsRemaining = secondsUntilNextAnnouncement
        let minutesRemaining = secondsRemaining / 60
        let secondsInMinute = secondsRemaining % 60
        
        var message = "\(display)"
        if secondsRemaining > 0 {
            if minutesRemaining > 0 {
                message += ", next in \(minutesRemaining) minute\(minutesRemaining == 1 ? "" : "s") and \(secondsInMinute) second\(secondsInMinute == 1 ? "" : "s")"
            } else {
                message += ", next in \(secondsRemaining) second\(secondsRemaining == 1 ? "" : "s")"
            }
        }
        
        audioCoach.speak(message, settings: settings)
    }
    
    func announceHeartRateOnly() {
        updateHeartRateAvailability()
        guard settings.audioEnabled, !isHeartRateMissing, let sample = latestSample else { return }
        
        let display = settings.displayMode == .bpm ? sample.bpm : sample.percent
        audioCoach.speak("\(display)", settings: settings)
    }

    private func resetAnnouncementSchedule() {
        stopCountdownTimer()
        lastHeartRateAnnounceTime = announcementClock()
        let interval = max(0, settings.heartRateSpeakIntervalSeconds)
        secondsUntilNextAnnouncement = interval
        // This timer is display-only. Speech is always driven by a fresh sample.
        guard interval > 0 else { return }
        startCountdownTimer()
    }

    private func startCountdownTimer() {
        stopCountdownTimer()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.updateAnnouncementCountdown()
            }
        }
    }
    
    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    /// Display-only: an expired countdown waits for a fresh Bluetooth reading.
    func updateAnnouncementCountdown() {
        let interval = max(0, settings.heartRateSpeakIntervalSeconds)
        guard interval > 0 else {
            secondsUntilNextAnnouncement = 0
            return
        }
        guard let lastAnnouncement = lastHeartRateAnnounceTime else {
            secondsUntilNextAnnouncement = interval
            return
        }
        let remaining = Double(interval) - (announcementClock() - lastAnnouncement)
        secondsUntilNextAnnouncement = max(0, Int(ceil(remaining)))
    }

    private func receive(sample: HeartRateSample) {
        guard case .connected = connectionState else { return }
        // A zero reading is not a heartbeat and must not refresh stale data.
        guard sample.bpm > 0 else {
            updateHeartRateAvailability()
            return
        }
        NSLog("🟢 RunnerViewModel: receive(sample:) - \(sample.bpm) BPM")
        let adjustedSample = HeartRateSample(
            bpm: sample.bpm,
            percent: HeartRateConverter.percent(from: sample.bpm, maxHeartRate: settings.maxHeartRate),
            timestamp: sample.timestamp
        )
        latestSample = adjustedSample
        isHeartRateMissing = false
        lastWarningTime = 0
        NSLog("🟢 RunnerViewModel: Latest sample updated to \(adjustedSample.bpm) BPM")
        doHeartBeat(bpm: adjustedSample.bpm)

        let now = announcementClock()
        if settings.audioEnabled && lastSupportReminderTime == nil {
            lastSupportReminderTime = now
        }
        let isFirstSample = !hasAnnouncedFirstSample
        hasAnnouncedFirstSample = true
        let interval = max(0, settings.heartRateSpeakIntervalSeconds)
        if interval > 0 && countdownTimer == nil { startCountdownTimer() }

        // Match HeartMonitor: instructions take precedence over pulse speech.
        if isRunning {
            let newCues = sessionEngine.consume(sample: adjustedSample, settings: settings, now: adjustedSample.timestamp)
            cues = newCues
            if newCues.contains(.sessionCompleted) {
                // Completion ends execution, not monitoring or the final instruction.
                isRunning = false
                runningSession = nil
                updateWorkoutDeletionProtection()
            }
            let speechCues = newCues.filter { !message(for: $0).isEmpty }
            if !speechCues.isEmpty {
                for cue in speechCues {
                    let text = message(for: cue)
                    lastDisplayedCue = cue
                    lastMessage = text
                    audioCoach.speak(text, settings: settings)
                }
                if isFirstSample { lastHeartRateAnnounceTime = now }
                updateAnnouncementCountdown()
                return
            }
        }

        // Never announce an old pulse behind the support message. Workout
        // instructions above always take precedence; a due reminder can wait.
        if settings.audioEnabled, !hasPurchased(),
           let lastReminder = lastSupportReminderTime,
           now - lastReminder >= Self.supportReminderInterval {
            lastSupportReminderTime = now
            lastHeartRateAnnounceTime = now
            audioCoach.speak(Self.supportReminder, settings: settings)
            updateAnnouncementCountdown()
            return
        }

        let elapsed = lastHeartRateAnnounceTime.map { now - $0 } ?? .infinity
        if isFirstSample || interval == 0 || elapsed >= Double(interval) {
            // Consume one interval even when busy speech discards this pulse.
            // No catch-up queue, and no repeated attempts during the cooldown.
            lastHeartRateAnnounceTime = now
            let display = settings.displayMode == .bpm ? adjustedSample.bpm : adjustedSample.percent
            audioCoach.speakAutomaticPulse("\(display)", settings: settings)
        }
        updateAnnouncementCountdown()
    }

    private func doHeartBeat(bpm: Int) {
        // Update last beat time
        lastBeatTime = Date()
        
        // Start/update heart beat timer based on BPM
        if bpm > 0 && (bpm != previousHeartRate || heartBeatTimer == nil) {
            stopHeartBeatTimer()
            previousHeartRate = bpm
            
            // Trigger animation immediately on first beat
            heartBeatTrigger += 1
            
            // Calculate interval: 60 seconds / BPM = seconds per beat
            let interval = 60.0 / Double(bpm)
            heartBeatTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.heartBeatTrigger += 1
                }
            }
        }
        
        // Start warning timer to detect lost heart rate connection
        startHeartRateLossWarningTimer()
    }

    private func stopHeartBeatTimer() {
        heartBeatTimer?.invalidate()
        heartBeatTimer = nil
    }
    
    private func startHeartRateLossWarningTimer() {
        beginHeartRateWatchdogTask()
        guard heartRateLossWarningTimer == nil else { return }
        let timer = Timer(fire: Date().addingTimeInterval(0.5), interval: 0.5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.updateHeartRateAvailability()
            }
        }
        heartRateLossWarningTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func beginHeartRateWatchdogTask() {
        guard heartRateWatchdogTask == .invalid, lastBeatTime != nil,
              settings.audioEnabled, UIApplication.shared.applicationState != .active else { return }
        let requestID = UUID()
        heartRateWatchdogRequestID = requestID
        // Pulse callbacks stop waking us when transmission stops. Request a finite
        // window for detecting that gap; this is not an indefinite background timer.
        heartRateWatchdogTask = UIApplication.shared.beginBackgroundTask(withName: "Runner.heartRateWatchdog") { [weak self] in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.heartRateWatchdogRequestID == requestID else { return }
                self.endHeartRateWatchdogTask()
                self.updateHeartRateAvailability()
                NSLog("🟢 Heart rate watchdog background time expired")
            }
        }
        if heartRateWatchdogTask == .invalid { heartRateWatchdogRequestID = nil }
    }

    private func endHeartRateWatchdogTask() {
        guard heartRateWatchdogTask != .invalid else { return }
        let task = heartRateWatchdogTask
        heartRateWatchdogTask = .invalid
        heartRateWatchdogRequestID = nil
        UIApplication.shared.endBackgroundTask(task)
    }

    func updateHeartRateAvailability(now: Date = Date()) {
        guard let lastBeatTime else { return }
        let elapsed = now.timeIntervalSince(lastBeatTime)
        guard elapsed >= Self.heartRateDisplayTimeout else { return }
        if !isHeartRateMissing {
            NSLog("🟢 Heart rate display marked stale after %.1f seconds", elapsed)
        }
        isHeartRateMissing = true
        latestSample = nil
        hasAnnouncedFirstSample = false
        stopHeartBeatTimer()
        // GUI freshness is independent of both speech throttling and warnings.
        guard elapsed > Self.heartRateWarningInterval else { return }
        // Like HeartMonitor, warn during pulse monitoring, not only during workouts.
        if settings.audioEnabled && elapsed - lastWarningTime > Self.heartRateWarningInterval {
            NSLog("🟢 Heart rate missing for %.0f seconds; requesting warning", elapsed)
            audioCoach.speak("Warning: No heart rate received for \(Int(elapsed.rounded())) seconds!", settings: settings)
            lastWarningTime = elapsed
        }
        // AudioCoach owns the background assertion while the warning speaks.
        endHeartRateWatchdogTask()
    }
    
    private func stopHeartRateLossWarningTimer() {
        heartRateLossWarningTimer?.invalidate()
        heartRateLossWarningTimer = nil
    }

    private func message(for cue: SessionCue) -> String {
        switch cue {
        case .warmupStarted(let minutes):
            return "Warm up \(minutes) minutes."
        case .warmupMinutesRemaining(let minutes):
            return "\(minutes) minutes left of warm up."
        case .blockStarted:
            return ""
        case .blockCompleted:
            return "Block completed."
        case .sessionCompleted:
            return "Good job. Fartlek completed."
        case .slowDownToStart(let target):
            return "Heart rate too high. Slow down to \(cueTargetText(percent: target)) before starting the first interval."
        case .slowDown(let target, let repetition, let total):
            return "Rep \(repetition) of \(total). Slow down to \(cueTargetText(percent: target)) to recover."
        case .speedUp(let target, let repetition, let total):
            return "Rep \(repetition) of \(total). Speed up to \(cueTargetText(percent: target))."
        }
    }

    private func cueTargetText(percent: Int) -> String {
        settings.displayMode == .bpm
            ? "\(HeartRateConverter.bpm(from: percent, maxHeartRate: settings.maxHeartRate)) BPM"
            : "\(percent)%"
    }
}
