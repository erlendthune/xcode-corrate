import Combine
import Foundation

@MainActor
final class RunnerViewModel: ObservableObject {
    @Published private(set) var connectionState: HeartRateConnectionState = .disconnected
    @Published private(set) var devices: [HeartRateDevice] = []
    @Published private(set) var latestSample: HeartRateSample?
    @Published private(set) var isHeartRateMissing = false
    @Published private(set) var cues: [SessionCue] = []
    @Published private(set) var lastMessage: String = ""
    @Published private(set) var isRunning = false
    @Published private(set) var settings = AppSettings.default
    @Published var currentSession: SessionTemplate
    @Published private(set) var heartBeatTrigger = 0  // Incremented to trigger animation
    @Published private(set) var secondsUntilNextAnnouncement: Int = 0

    let sessionEngine: SessionEngine
    private let heartRateService: HeartRateService
    private let settingsStore: SettingsStore
    private let sessionStore: SessionStore
    private let audioCoach: AudioCoach
    private var heartRateAnnounceTimer: Timer?
    private var lastHeartRateAnnounceTime: Date?
    private var settingsSaveTask: Task<Void, Never>?
    private var heartBeatTimer: Timer?
    private var heartRateLossWarningTimer: Timer?
    private var countdownTimer: Timer?
    private var previousHeartRate: Int = 0
    private var hasAnnouncedFirstSample = false
    private var lastBeatTime: Date?
    private var lastWarningTime: Double = 0

    convenience init(environment: AppEnvironment) {
        self.init(heartRateService: environment.heartRateService,
                  settingsStore: environment.settingsStore,
                  sessionStore: environment.sessionStore,
                  sessionEngine: environment.sessionEngine,
                  audioCoach: environment.audioCoach)
    }

    init(heartRateService: HeartRateService, settingsStore: SettingsStore,
         sessionStore: SessionStore, sessionEngine: SessionEngine, audioCoach: AudioCoach) {
        self.sessionEngine = sessionEngine
        self.heartRateService = heartRateService
        self.settingsStore = settingsStore
        self.sessionStore = sessionStore
        self.audioCoach = audioCoach
        currentSession = BuiltinSessions.flatFartlek

        heartRateService.onConnectionStateChanged = { [weak self] state in
            self?.receive(connectionState: state)
        }
        heartRateService.onSample = { [weak self] sample in
            self?.receive(sample: sample)
        }
        heartRateService.onDevicesChanged = { [weak self] devices in
            self?.devices = devices
        }
    }

    private func receive(connectionState state: HeartRateConnectionState) {
        connectionState = state
        switch state {
        case .disconnected:
            latestSample = nil
            isHeartRateMissing = lastBeatTime != nil
            hasAnnouncedFirstSample = false
            stopHeartBeatTimer()
        case .connecting:
            latestSample = nil
            isHeartRateMissing = false
            hasAnnouncedFirstSample = false
            lastBeatTime = Date()
            lastWarningTime = 0
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
        if !isRunning, let sessions = try? await sessionStore.loadSessions(),
           let savedSession = sessions.first(where: {
               $0.id == currentSession.id || ($0.isBuiltin && currentSession.isBuiltin && $0.name == currentSession.name)
           }) {
            currentSession = savedSession
        }
        startHeartRateAnnounceTimer()
        
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
        heartRateService.disconnect()
        latestSample = nil
        isHeartRateMissing = false
        stopHeartBeatTimer()
        hasAnnouncedFirstSample = false
        lastWarningTime = 0
        stopHeartRateLossWarningTimer()
    }

    func connect(to device: HeartRateDevice) {
        heartRateService.connect(to: device)
    }

    func startSession() {
        sessionEngine.reset(session: currentSession)
        cues = []
        lastMessage = ""
        isRunning = true
        lastWarningTime = 0
        startHeartRateLossWarningTimer()
        audioCoach.activate()
        audioCoach.speak("Session started.", settings: settings)
    }

    func stopSession() {
        isRunning = false
        cues = []
        audioCoach.speak("Fartlek stopped.", settings: settings)
        audioCoach.deactivate()
        stopHeartBeatTimer()
    }

    func selectSession(_ session: SessionTemplate) {
        currentSession = session
    }

    func updateSettings(_ updated: AppSettings) {
        let intervalChanged = settings.heartRateSpeakIntervalSeconds != updated.heartRateSpeakIntervalSeconds
        settings = updated
        if intervalChanged { startHeartRateAnnounceTimer() }
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
            announceHeartRate()
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

    private func startHeartRateAnnounceTimer() {
        stopHeartRateAnnounceTimer()
        lastHeartRateAnnounceTime = Date()
        let interval = max(0, settings.heartRateSpeakIntervalSeconds)
        secondsUntilNextAnnouncement = interval
        // Zero means sample-driven speech, never a zero-duration repeating timer.
        guard interval > 0 else { return }
        
        heartRateAnnounceTimer = Timer.scheduledTimer(withTimeInterval: Double(interval), repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.updateAnnouncementSchedule()
            }
        }
        
        startCountdownTimer()
    }

    private func stopHeartRateAnnounceTimer() {
        heartRateAnnounceTimer?.invalidate()
        heartRateAnnounceTimer = nil
        stopCountdownTimer()
    }
    
    private func startCountdownTimer() {
        stopCountdownTimer()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.updateAnnouncementSchedule()
            }
        }
    }
    
    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    /// Bluetooth notifications wake the app in the background; timers alone do not.
    /// Share one deadline between sample delivery and foreground timer updates.
    private func updateAnnouncementSchedule(now: Date = Date()) {
        let interval = max(0, settings.heartRateSpeakIntervalSeconds)
        guard interval > 0 else {
            secondsUntilNextAnnouncement = 0
            return
        }
        guard let lastAnnouncement = lastHeartRateAnnounceTime else {
            lastHeartRateAnnounceTime = now
            secondsUntilNextAnnouncement = interval
            return
        }
        let remaining = Double(interval) - now.timeIntervalSince(lastAnnouncement)
        secondsUntilNextAnnouncement = max(0, Int(ceil(remaining)))
        guard remaining <= 0 else { return }
        // Never queue a burst of missed announcements after suspension.
        lastHeartRateAnnounceTime = now
        secondsUntilNextAnnouncement = interval
        announceHeartRate()
    }

    private func announceHeartRate() {
        updateHeartRateAvailability()
        guard !isHeartRateMissing, let sample = latestSample else { return }
        let display = settings.displayMode == .bpm ? sample.bpm : sample.percent
        audioCoach.speak("\(display)", settings: settings)
    }

    private func receive(sample: HeartRateSample) {
        guard case .connected = connectionState else { return }
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
        
        // At zero interval, announce every notification, even if BPM is unchanged.
        if !hasAnnouncedFirstSample || settings.heartRateSpeakIntervalSeconds == 0 {
            hasAnnouncedFirstSample = true
            announceHeartRate()
            lastHeartRateAnnounceTime = adjustedSample.timestamp
            secondsUntilNextAnnouncement = max(0, settings.heartRateSpeakIntervalSeconds)
        } else {
            // Like HeartMonitor's TimedSpeaking: run when Bluetooth wakes us,
            // even if iOS suspended the UI timers between notifications.
            updateAnnouncementSchedule(now: adjustedSample.timestamp)
        }
        
        guard isRunning else { return }
        let newCues = sessionEngine.consume(sample: adjustedSample, settings: settings, now: adjustedSample.timestamp)
        cues = newCues
        newCues.forEach { cue in
            let text = message(for: cue)
            guard !text.isEmpty else { return }
            lastMessage = text
            audioCoach.speak(text, settings: settings)
        }
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
        guard heartRateLossWarningTimer == nil else { return }
        heartRateLossWarningTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.updateHeartRateAvailability()
            }
        }
    }

    func updateHeartRateAvailability(now: Date = Date()) {
        guard let lastBeatTime else { return }
        let elapsed = now.timeIntervalSince(lastBeatTime)
        guard elapsed > 9.5 else { return }
        isHeartRateMissing = true
        latestSample = nil
        hasAnnouncedFirstSample = false
        stopHeartBeatTimer()
        if isRunning && elapsed - lastWarningTime > 9.5 {
            audioCoach.speak("Warning: No heart rate received for \(Int(elapsed)) seconds!", settings: settings)
            lastWarningTime = elapsed
        }
    }
    
    private func stopHeartRateLossWarningTimer() {
        heartRateLossWarningTimer?.invalidate()
        heartRateLossWarningTimer = nil
    }

    private func message(for cue: SessionCue) -> String {
        switch cue {
        case .warmupStarted(let minutes):
            return "Warm up \(minutes) minutes to start fartlek."
        case .warmupMinutesRemaining(let minutes):
            return "\(minutes) minutes left of warm up."
        case .blockStarted:
            return ""
        case .blockCompleted:
            return "Block completed."
        case .sessionCompleted:
            return "Good job. Fartlek completed."
        case .slowDownToStart(let target):
            return "Heart rate too high. Slow down to \(target) to start the first iteration of fartlek."
        case .slowDown(let target, let repetition, let total):
            return "Iteration \(repetition) of \(total) completed. Slow down to \(target)."
        case .speedUp(let target, let repetition, let total):
            return "Iteration \(repetition) of \(total). Speed up to \(target)."
        }
    }
}
