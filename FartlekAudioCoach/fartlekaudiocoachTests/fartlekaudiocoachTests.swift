//
//  fartlekaudiocoachTests.swift
//  fartlekaudiocoachTests
//
//  Created by Erlend Thune on 15/08/2026.
//

import Foundation
import Testing
@testable import fartlekaudiocoach

struct fartlekaudiocoachTests {

    @MainActor
    @Test func connectedMonitorDoesNotReconnectWhenSelectedAgain() {
        let heartRate = BackgroundTestHeartRateService()
        let model = RunnerViewModel(heartRateService: heartRate,
                                    settingsStore: BackgroundTestSettingsStore(),
                                    sessionStore: BackgroundTestSessionStore(),
                                    sessionEngine: DefaultSessionEngine(),
                                    audioCoach: BackgroundTestAudioCoach())
        defer {
            model.stopSession()
            model.disconnect()
        }
        let connected = HeartRateDevice(id: UUID(), name: "Connected monitor")
        heartRate.onConnectionStateChanged?(.connected(connected))
        model.startSession()
        heartRate.onSample?(HeartRateSample(bpm: 100, percent: 0, timestamp: Date()))
        let reading = model.latestSample
        let snapshot = model.runningSession
        model.connect(to: HeartRateDevice(id: connected.id, name: "Advertised name"))
        #expect(heartRate.connectionRequests.isEmpty)
        #expect(model.connectionState == .connected(connected))
        #expect(model.latestSample == reading)
        #expect(model.runningSession == snapshot)
        #expect(model.isRunning)
        #expect(model.availableDevices == [connected])
        let other = HeartRateDevice(id: UUID(), name: "Other monitor")
        model.connect(to: other)
        #expect(heartRate.connectionRequests == [other])
    }

    @MainActor
    @Test(arguments: [true, false])
    func coachingUsesRunnerTerminology(displayInBPM: Bool) {
        let heartRate = BackgroundTestHeartRateService()
        let audio = BackgroundTestAudioCoach()
        let model = RunnerViewModel(heartRateService: heartRate,
                                    settingsStore: BackgroundTestSettingsStore(),
                                    sessionStore: BackgroundTestSessionStore(),
                                    sessionEngine: DefaultSessionEngine(), audioCoach: audio)
        defer { model.disconnect() }
        var settings = model.settings
        settings.audioEnabled = true
        settings.maxHeartRate = 100
        settings.displayMode = displayInBPM ? .bpm : .percent
        model.updateSettings(settings)
        model.selectSession(SessionTemplate(name: "Terminology test", blocks: [
            SessionBlock(repetitions: 2, lowerTargetPercent: 60, upperTargetPercent: 85)
        ]))
        heartRate.onConnectionStateChanged?(.connected(HeartRateDevice(id: UUID(), name: "Monitor")))
        model.startSession()
        heartRate.onSample?(HeartRateSample(bpm: 75, percent: 0, timestamp: Date()))
        let lower = displayInBPM ? "60 BPM" : "60%"
        let upper = displayInBPM ? "85 BPM" : "85%"
        let instructions: [(Int, String)] = [
            (75, "Heart rate too high. Slow down to \(lower) before starting the first interval."),
            (60, "Rep 1 of 2. Speed up to \(upper)."),
            (85, "Rep 1 of 2. Slow down to \(lower) to recover."),
            (60, "Rep 2 of 2. Speed up to \(upper)."),
            (85, "Rep 2 of 2. Slow down to \(lower) to recover."),
            (60, "Good job. Fartlek completed.")
        ]
        for (bpm, instruction) in instructions {
            heartRate.onSample?(HeartRateSample(bpm: bpm, percent: 0, timestamp: Date()))
            #expect(model.lastMessage == instruction)
            #expect(audio.messages.last == instruction)
        }
        #expect(!model.isRunning)
    }

    @MainActor
    @Test func connectedMonitorAppearsWithoutScanning() {
        let heartRate = BackgroundTestHeartRateService()
        let model = RunnerViewModel(heartRateService: heartRate,
                                    settingsStore: BackgroundTestSettingsStore(),
                                    sessionStore: BackgroundTestSessionStore(),
                                    sessionEngine: DefaultSessionEngine(),
                                    audioCoach: BackgroundTestAudioCoach())
        defer { model.disconnect() }
        let connected = HeartRateDevice(id: UUID(), name: "Connected monitor")
        let other = HeartRateDevice(id: UUID(), name: "Other monitor")
        #expect(model.availableDevices.isEmpty)
        heartRate.onConnectionStateChanged?(.connected(connected))
        #expect(model.devices.isEmpty)
        #expect(model.availableDevices == [connected])

        let rediscovered = HeartRateDevice(id: connected.id, name: "Advertised name")
        heartRate.onDevicesChanged?([other, rediscovered])
        #expect(model.availableDevices == [connected, other])
        #expect(model.devices == [other, rediscovered])

        // Refresh may clear scan results, but the connection is still known.
        heartRate.onDevicesChanged?([])
        #expect(model.availableDevices == [connected])
        heartRate.onConnectionStateChanged?(.disconnected)
        #expect(model.availableDevices.isEmpty)
        heartRate.onDevicesChanged?([other])
        #expect(model.availableDevices == [other])
    }

    @MainActor
    @Test func manualStopClearsLastCueAndItsFormattingCache() {
        let heartRate = BackgroundTestHeartRateService()
        let model = RunnerViewModel(heartRateService: heartRate,
                                    settingsStore: BackgroundTestSettingsStore(),
                                    sessionStore: BackgroundTestSessionStore(),
                                    sessionEngine: DefaultSessionEngine(),
                                    audioCoach: BackgroundTestAudioCoach())
        defer { model.disconnect() }
        model.selectSession(SessionTemplate(name: "Stop test", blocks: [
            SessionBlock(repetitions: 1, lowerTargetPercent: 60, upperTargetPercent: 85)
        ]))
        heartRate.onConnectionStateChanged?(.connected(HeartRateDevice(id: UUID(), name: "Monitor")))
        model.startSession()
        for _ in 0..<2 {
            heartRate.onSample?(HeartRateSample(bpm: 150, percent: 0, timestamp: Date()))
        }
        #expect(!model.lastMessage.isEmpty)
        model.stopSession()
        #expect(model.lastMessage.isEmpty)
        #expect(model.cues.isEmpty)

        model.toggleDisplayMode()
        #expect(model.lastMessage.isEmpty)
        var settings = model.settings
        settings.maxHeartRate = 200
        model.updateSettings(settings)
        #expect(model.lastMessage.isEmpty)
    }

    @MainActor
    @Test func runningSessionSummaryUsesStartSnapshot() {
        let heartRate = BackgroundTestHeartRateService()
        let model = RunnerViewModel(heartRateService: heartRate,
                                    settingsStore: BackgroundTestSettingsStore(),
                                    sessionStore: BackgroundTestSessionStore(),
                                    sessionEngine: DefaultSessionEngine(),
                                    audioCoach: BackgroundTestAudioCoach())
        defer { model.disconnect() }
        let original = SessionTemplate(name: "Snapshot workout", notes: "Keep these notes", blocks: [
            SessionBlock(repetitions: 3, lowerTargetPercent: 60, upperTargetPercent: 85),
            SessionBlock(repetitions: 2, lowerTargetPercent: 65, upperTargetPercent: 90)
        ], warmupSeconds: 95)
        #expect(model.runningSession == nil)
        model.selectSession(original)
        model.startSession()
        #expect(model.runningSession == original)

        // Even a stale caller changing selected fields cannot change the run.
        model.currentSession.name = "Changed selection"
        model.currentSession.notes = "Changed notes"
        model.currentSession.warmupSeconds = 10
        model.currentSession.blocks[0].repetitions = 8
        #expect(model.runningSession == original)
        model.startSession()
        #expect(model.runningSession == original)

        model.stopSession()
        #expect(model.runningSession == nil)
        #expect(!model.isRunning)
        let next = model.currentSession
        model.startSession()
        #expect(model.runningSession == next)
        model.stopSession()
    }

    @MainActor
    @Test(arguments: [true, false])
    func naturalCompletionEndsExecutionButKeepsMonitoring(audioEnabled: Bool) {
        let heartRate = BackgroundTestHeartRateService()
        let audio = BackgroundTestAudioCoach()
        let engine = BackgroundTestSessionEngine()
        let model = RunnerViewModel(heartRateService: heartRate,
                                    settingsStore: BackgroundTestSettingsStore(),
                                    sessionStore: BackgroundTestSessionStore(),
                                    sessionEngine: engine, audioCoach: audio)
        defer { model.disconnect() }
        var settings = model.settings
        settings.audioEnabled = audioEnabled
        settings.maxHeartRate = 100
        settings.heartRateSpeakIntervalSeconds = 0
        model.updateSettings(settings)
        model.selectSession(SessionTemplate(name: "Completion test", blocks: [
            SessionBlock(repetitions: 1, lowerTargetPercent: 60, upperTargetPercent: 85)
        ]))
        let device = HeartRateDevice(id: UUID(), name: "Test monitor")
        heartRate.onConnectionStateChanged?(.connected(device))
        model.startSession()
        func deliver(_ bpm: Int) {
            heartRate.onSample?(HeartRateSample(bpm: bpm, percent: 0, timestamp: Date()))
        }
        deliver(75)
        deliver(75)
        deliver(60)
        deliver(85)
        #expect(model.isRunning)
        let pulseAttempts = audio.automaticPulseAttempts.count
        deliver(60)

        let finalCues: [SessionCue] = [.blockCompleted(blockIndex: 0), .sessionCompleted]
        let finalMessage = "Good job. Fartlek completed."
        #expect(!model.isRunning)
        #expect(model.runningSession == nil)
        #expect(model.cues == finalCues)
        #expect(model.lastMessage == finalMessage)
        #expect(audio.messages.filter { $0 == finalMessage }.count == (audioEnabled ? 1 : 0))
        #expect(!audio.messages.contains("Fartlek stopped."))
        #expect(audio.deactivationCount == 0)
        #expect(audio.automaticPulseAttempts.count == pulseAttempts)

        // Later readings monitor normally, without feeding the completed engine.
        let consumedSamples = engine.consumeCount
        deliver(110)
        deliver(100)
        #expect(engine.consumeCount == consumedSamples)
        #expect(model.latestSample?.bpm == 100)
        #expect(model.monitorStatus == "Connected to Test monitor")
        #expect(model.cues == finalCues)
        #expect(model.lastMessage == finalMessage)
        #expect(audio.messages.filter { $0 == finalMessage }.count == (audioEnabled ? 1 : 0))
        #expect(audio.automaticPulseAttempts.count == pulseAttempts + (audioEnabled ? 2 : 0))
        #expect(audio.deactivationCount == 0)

        model.updateHeartRateAvailability(now: Date().addingTimeInterval(11))
        #expect(model.isHeartRateMissing)
        #expect(audio.messages.contains(where: { $0.contains("No heart rate received") }) == audioEnabled)
    }

    @MainActor
    @Test(arguments: [true, false], [true, false])
    func supportRemindersRespectAudioAndPurchase(audioEnabled: Bool, purchased: Bool) {
        let heartRate = BackgroundTestHeartRateService()
        let audio = BackgroundTestAudioCoach()
        var elapsed: TimeInterval = 0
        var hasPurchased = purchased
        let model = RunnerViewModel(heartRateService: heartRate,
                                    settingsStore: BackgroundTestSettingsStore(),
                                    sessionStore: BackgroundTestSessionStore(),
                                    sessionEngine: DefaultSessionEngine(), audioCoach: audio,
                                    announcementClock: { elapsed },
                                    hasPurchased: { hasPurchased })
        defer { model.disconnect() }
        var settings = model.settings
        settings.audioEnabled = audioEnabled
        model.updateSettings(settings)
        heartRate.onConnectionStateChanged?(.connected(HeartRateDevice(id: UUID(), name: "Monitor")))
        func deliver(at seconds: TimeInterval) {
            elapsed = seconds
            heartRate.onSample?(HeartRateSample(bpm: 100, percent: 54, timestamp: Date()))
        }
        func reminderCount() -> Int {
            audio.messages.filter { $0.hasPrefix("If you enjoy using the app") }.count
        }
        let shouldRemind = audioEnabled && !purchased
        deliver(at: 0)
        deliver(at: 599)
        #expect(reminderCount() == 0)
        let pulseAttempts = audio.automaticPulseAttempts.count
        deliver(at: 600)
        #expect(reminderCount() == (shouldRemind ? 1 : 0))
        if shouldRemind {
            #expect(audio.automaticPulseAttempts.count == pulseAttempts)
        }
        deliver(at: 600)
        #expect(reminderCount() == (shouldRemind ? 1 : 0))
        deliver(at: 1200)
        #expect(reminderCount() == (shouldRemind ? 2 : 0))
        // A suspension/reconnect never replays every missed reminder.
        deliver(at: 3600)
        #expect(reminderCount() == (shouldRemind ? 3 : 0))
        hasPurchased = true
        deliver(at: 4200)
        deliver(at: 4800)
        #expect(reminderCount() == (shouldRemind ? 3 : 0))
    }

    @Test(arguments: [1, 2, 8])
    func configuredIterationsAreCompleted(iterations: Int) {
        let engine = DefaultSessionEngine()
        var settings = AppSettings.default
        settings.displayMode = .percent
        let session = SessionTemplate(name: "Test", blocks: [
            SessionBlock(repetitions: iterations, lowerTargetPercent: 60, upperTargetPercent: 85)
        ])
        engine.reset(session: session)
        let now = Date()
        func consume(_ percent: Int) -> [SessionCue] {
            engine.consume(sample: HeartRateSample(bpm: percent, percent: percent, timestamp: now),
                           settings: settings, now: now)
        }
        #expect(consume(75).isEmpty)
        #expect(consume(75) == [.slowDownToStart(target: 60)])
        #expect(consume(60) == [.speedUp(target: 85, repetition: 1, total: iterations)])
        for iteration in 1...iterations {
            #expect(consume(85) == [.slowDown(target: 60, repetition: iteration, total: iterations)])
            if iteration == iterations {
                #expect(consume(60) == [.blockCompleted(blockIndex: 0), .sessionCompleted])
            } else {
                #expect(consume(60) == [.speedUp(target: 85, repetition: iteration + 1, total: iterations)])
            }
        }
        #expect(consume(85).isEmpty)
    }

    @Test func configuredWarmupWaitsForMinuteBoundary() {
        let engine = DefaultSessionEngine()
        engine.reset(session: SessionTemplate(name: "Test", blocks: [
            SessionBlock(repetitions: 1, lowerTargetPercent: 70, upperTargetPercent: 80)
        ], warmupMinutes: 5))
        let start = Date()
        func consume(after seconds: TimeInterval) -> [SessionCue] {
            let now = start.addingTimeInterval(seconds)
            return engine.consume(sample: HeartRateSample(bpm: 100, percent: 60, timestamp: now),
                                  settings: .default, now: now)
        }
        #expect(consume(after: 0) == [.warmupStarted(minutes: 5)])
        #expect(consume(after: 1).isEmpty)
        #expect(consume(after: 59).isEmpty)
        #expect(consume(after: 60) == [.warmupMinutesRemaining(4)])
    }

    @MainActor
    @Test func bluetoothSamplesScheduleSpeechWithoutTimers() {
        let heartRate = BackgroundTestHeartRateService()
        let audio = BackgroundTestAudioCoach()
        var elapsed: TimeInterval = 0
        let model = RunnerViewModel(heartRateService: heartRate,
                                    settingsStore: BackgroundTestSettingsStore(),
                                    sessionStore: BackgroundTestSessionStore(),
                                    sessionEngine: DefaultSessionEngine(), audioCoach: audio,
                                    announcementClock: { elapsed })
        var settings = model.settings
        settings.audioEnabled = true
        model.updateSettings(settings)
        defer { model.disconnect() }
        let device = HeartRateDevice(id: UUID(), name: "Test monitor")
        heartRate.onConnectionStateChanged?(.connected(device))
        let start = Date()
        let interval = AppSettings.default.heartRateSpeakIntervalSeconds
        func deliver(after seconds: Int) {
            elapsed = Double(seconds)
            heartRate.onSample?(HeartRateSample(bpm: 100, percent: 54,
                                               timestamp: start.addingTimeInterval(Double(seconds))))
        }
        // Synchronous delivery needs no countdown timer or run-loop ticks.
        deliver(after: 0)
        #expect(audio.messages.count == 1)
        deliver(after: interval - 1)
        #expect(audio.messages.count == 1)
        #expect(model.secondsUntilNextAnnouncement == 1)
        deliver(after: interval)
        #expect(audio.messages.count == 2)
        #expect(model.secondsUntilNextAnnouncement == interval)
        // A long suspension produces one current cue, never a catch-up queue.
        deliver(after: interval * 10)
        #expect(audio.messages.count == 3)
        deliver(after: interval * 10)
        #expect(audio.messages.count == 3)
        #expect(model.secondsUntilNextAnnouncement == interval)
    }

    @MainActor
    @Test func bluetoothSamplesAdvanceWarmupAfterSuspension() {
        let heartRate = BackgroundTestHeartRateService()
        let audio = BackgroundTestAudioCoach()
        let model = RunnerViewModel(heartRateService: heartRate,
                                    settingsStore: BackgroundTestSettingsStore(),
                                    sessionStore: BackgroundTestSessionStore(),
                                    sessionEngine: DefaultSessionEngine(), audioCoach: audio)
        var settings = model.settings
        settings.audioEnabled = true
        model.updateSettings(settings)
        defer {
            model.stopSession()
            model.disconnect()
        }
        model.currentSession = SessionTemplate(name: "Background test", blocks: [
            SessionBlock(repetitions: 1, lowerTargetPercent: 70, upperTargetPercent: 80)
        ], warmupMinutes: 5)
        heartRate.onConnectionStateChanged?(.connected(HeartRateDevice(id: UUID(), name: "Test monitor")))
        model.startSession()
        let start = Date()
        func deliver(after seconds: Int) {
            heartRate.onSample?(HeartRateSample(bpm: 100, percent: 54,
                                               timestamp: start.addingTimeInterval(Double(seconds))))
        }
        // Synchronous sample delivery: no UI timers or run-loop ticks are needed.
        deliver(after: 0)
        #expect(model.cues == [.warmupStarted(minutes: 5)])
        deliver(after: 60)
        #expect(model.cues == [.warmupMinutesRemaining(4)])
        deliver(after: 240)
        #expect(model.cues == [.warmupMinutesRemaining(1)])
        #expect(!audio.messages.contains("3 minutes left of warm up."))
        #expect(!audio.messages.contains("2 minutes left of warm up."))
        deliver(after: 300)
        deliver(after: 301)
        #expect(model.cues == [.speedUp(
            target: 80,
            repetition: 1, total: 1
        )])
        #expect(audio.messages.contains(model.lastMessage))
    }

    @MainActor
    @Test func speechIntervalChangesApplyImmediatelyAndZeroSpeaksEverySample() {
        let heartRate = BackgroundTestHeartRateService()
        let audio = BackgroundTestAudioCoach()
        var elapsed: TimeInterval = 0
        let model = RunnerViewModel(heartRateService: heartRate,
                                    settingsStore: BackgroundTestSettingsStore(),
                                    sessionStore: BackgroundTestSessionStore(),
                                    sessionEngine: DefaultSessionEngine(), audioCoach: audio,
                                    announcementClock: { elapsed })
        defer { model.disconnect() }
        heartRate.onConnectionStateChanged?(.connected(HeartRateDevice(id: UUID(), name: "Test monitor")))
        var settings = model.settings
        settings.audioEnabled = true
        settings.heartRateSpeakIntervalSeconds = 10
        model.updateSettings(settings)
        func deliver(at date: Date) {
            heartRate.onSample?(HeartRateSample(bpm: 100, percent: 54, timestamp: date))
        }
        deliver(at: Date())
        #expect(audio.messages.count == 1)

        settings.heartRateSpeakIntervalSeconds = 5
        model.updateSettings(settings)
        #expect(model.settings.heartRateSpeakIntervalSeconds == 5)
        #expect(model.secondsUntilNextAnnouncement == 5)
        // Synchronous delivery does not allow any foreground timers to fire.
        elapsed = 4
        deliver(at: Date())
        #expect(audio.messages.count == 1)
        elapsed = 5
        deliver(at: Date())
        #expect(audio.messages.count == 2)

        settings.heartRateSpeakIntervalSeconds = 0
        model.updateSettings(settings)
        #expect(model.secondsUntilNextAnnouncement == 0)
        let sameTimestamp = Date()
        deliver(at: sameTimestamp)
        deliver(at: sameTimestamp)
        #expect(audio.messages.count == 4)

        settings.audioEnabled = false
        model.updateSettings(settings)
        deliver(at: sameTimestamp)
        #expect(audio.messages.count == 4)

        settings.audioEnabled = true
        settings.heartRateSpeakIntervalSeconds = 5
        model.updateSettings(settings)
        let resumedAt = Date()
        deliver(at: resumedAt)
        #expect(audio.messages.count == 4)
        elapsed += 5
        deliver(at: resumedAt.addingTimeInterval(5))
        #expect(audio.messages.count == 5)
    }

    @MainActor
    @Test func countdownNeverSpeaksAndSensorTimestampsDoNotControlThrottle() {
        let heartRate = BackgroundTestHeartRateService()
        let audio = BackgroundTestAudioCoach()
        var elapsed: TimeInterval = 0
        let model = RunnerViewModel(heartRateService: heartRate,
                                    settingsStore: BackgroundTestSettingsStore(),
                                    sessionStore: BackgroundTestSessionStore(),
                                    sessionEngine: DefaultSessionEngine(), audioCoach: audio,
                                    announcementClock: { elapsed })
        defer { model.disconnect() }
        var settings = model.settings
        settings.audioEnabled = true
        settings.heartRateSpeakIntervalSeconds = 10
        model.updateSettings(settings)
        heartRate.onConnectionStateChanged?(.connected(HeartRateDevice(id: UUID(), name: "Test monitor")))
        heartRate.onSample?(HeartRateSample(bpm: 100, percent: 54, timestamp: .distantFuture))
        #expect(audio.automaticPulseAttempts.count == 1)

        elapsed = 10
        model.updateAnnouncementCountdown()
        model.updateAnnouncementCountdown()
        #expect(model.secondsUntilNextAnnouncement == 0)
        #expect(audio.automaticPulseAttempts.count == 1)
        heartRate.onSample?(HeartRateSample(bpm: 110, percent: 60, timestamp: .distantPast))
        #expect(audio.automaticPulseAttempts.count == 2)
        #expect(model.secondsUntilNextAnnouncement == 10)
    }

    @MainActor
    @Test func busyPulseDropsConsumeAnIntervalWithoutRetryingOrCatchingUp() {
        let heartRate = BackgroundTestHeartRateService()
        let audio = BackgroundTestAudioCoach()
        var elapsed: TimeInterval = 0
        let model = RunnerViewModel(heartRateService: heartRate,
                                    settingsStore: BackgroundTestSettingsStore(),
                                    sessionStore: BackgroundTestSessionStore(),
                                    sessionEngine: DefaultSessionEngine(), audioCoach: audio,
                                    announcementClock: { elapsed })
        defer { model.disconnect() }
        var settings = model.settings
        settings.audioEnabled = true
        settings.heartRateSpeakIntervalSeconds = 10
        model.updateSettings(settings)
        heartRate.onConnectionStateChanged?(.connected(HeartRateDevice(id: UUID(), name: "Test monitor")))
        func deliver(after seconds: TimeInterval) {
            elapsed = seconds
            heartRate.onSample?(HeartRateSample(bpm: 100, percent: 54, timestamp: Date()))
        }
        audio.isBusy = true
        deliver(after: 0)
        deliver(after: 9)
        #expect(audio.automaticPulseAttempts.count == 1)
        deliver(after: 10)
        #expect(audio.automaticPulseAttempts.count == 2)
        #expect(audio.messages.isEmpty)
        audio.isBusy = false
        deliver(after: 11)
        #expect(audio.messages.isEmpty)
        deliver(after: 20)
        #expect(audio.messages.count == 1)
        deliver(after: 200)
        #expect(audio.messages.count == 2)
        deliver(after: 200)
        #expect(audio.messages.count == 2)
    }

    @MainActor
    @Test func workoutInstructionsSuppressPulseEvenWithZeroInterval() {
        let heartRate = BackgroundTestHeartRateService()
        let audio = BackgroundTestAudioCoach()
        let model = RunnerViewModel(heartRateService: heartRate,
                                    settingsStore: BackgroundTestSettingsStore(),
                                    sessionStore: BackgroundTestSessionStore(),
                                    sessionEngine: DefaultSessionEngine(), audioCoach: audio)
        defer {
            model.stopSession()
            model.disconnect()
        }
        var settings = model.settings
        settings.audioEnabled = true
        settings.heartRateSpeakIntervalSeconds = 0
        model.updateSettings(settings)
        model.currentSession = SessionTemplate(name: "Priority test", blocks: [
            SessionBlock(repetitions: 1, lowerTargetPercent: 70, upperTargetPercent: 80)
        ], warmupMinutes: 5)
        heartRate.onConnectionStateChanged?(.connected(HeartRateDevice(id: UUID(), name: "Test monitor")))
        model.startSession()
        let start = Date()
        heartRate.onSample?(HeartRateSample(bpm: 100, percent: 54, timestamp: start))
        #expect(audio.messages.last == "Warm up 5 minutes.")
        #expect(audio.automaticPulseAttempts.isEmpty)
        heartRate.onSample?(HeartRateSample(bpm: 100, percent: 54, timestamp: start.addingTimeInterval(60)))
        #expect(audio.messages.last == "4 minutes left of warm up.")
        #expect(audio.automaticPulseAttempts.isEmpty)
        heartRate.onSample?(HeartRateSample(bpm: 100, percent: 54, timestamp: start.addingTimeInterval(61)))
        #expect(audio.automaticPulseAttempts.count == 1)
    }

    @MainActor
    @Test(arguments: [true, false])
    func heartRateLossWarningSurvivesReconnectUntilFreshData(audioEnabled: Bool) {
        let heartRate = BackgroundTestHeartRateService()
        let audio = BackgroundTestAudioCoach()
        let model = RunnerViewModel(heartRateService: heartRate,
                                    settingsStore: BackgroundTestSettingsStore(),
                                    sessionStore: BackgroundTestSessionStore(),
                                    sessionEngine: DefaultSessionEngine(), audioCoach: audio)
        defer {
            model.stopSession()
            model.disconnect()
        }
        var settings = model.settings
        settings.audioEnabled = audioEnabled
        model.updateSettings(settings)
        let device = HeartRateDevice(id: UUID(), name: "Test watch")
        heartRate.onConnectionStateChanged?(.connected(device))
        model.startSession()
        heartRate.onSample?(HeartRateSample(bpm: 100, percent: 54, timestamp: Date()))
        model.updateHeartRateAvailability(now: Date().addingTimeInterval(11))
        #expect(model.isHeartRateMissing)
        #expect(model.latestSample == nil)
        #expect(model.monitorStatus.contains("no heart rate received"))
        #expect(audio.messages.contains(where: { $0.contains("No heart rate received") }) == audioEnabled)

        heartRate.onConnectionStateChanged?(.disconnected)
        #expect(model.monitorStatus == "No monitor connected")
        #expect(model.isHeartRateMissing)
        heartRate.onConnectionStateChanged?(.scanning)
        #expect(model.isHeartRateMissing)
        heartRate.onConnectionStateChanged?(.connecting(device))
        #expect(model.isHeartRateMissing)
        heartRate.onConnectionStateChanged?(.connected(device))
        #expect(model.isHeartRateMissing)

        heartRate.onSample?(HeartRateSample(bpm: 110, percent: 60, timestamp: Date()))
        #expect(!model.isHeartRateMissing)
        #expect(model.latestSample?.bpm == 110)
        #expect(model.monitorStatus == "Connected to Test watch")
        model.disconnect()
        #expect(!model.isHeartRateMissing)
    }

    @MainActor
    @Test(arguments: [0, 10, 60])
    func displayFreshnessDoesNotWaitForSpeechInterval(speechInterval: Int) {
        let heartRate = BackgroundTestHeartRateService()
        let audio = BackgroundTestAudioCoach()
        let model = RunnerViewModel(heartRateService: heartRate,
                                    settingsStore: BackgroundTestSettingsStore(),
                                    sessionStore: BackgroundTestSessionStore(),
                                    sessionEngine: DefaultSessionEngine(), audioCoach: audio)
        defer { model.disconnect() }
        var settings = model.settings
        settings.audioEnabled = true
        settings.heartRateSpeakIntervalSeconds = speechInterval
        model.updateSettings(settings)
        heartRate.onConnectionStateChanged?(.connected(HeartRateDevice(id: UUID(), name: "Test monitor")))
        heartRate.onSample?(HeartRateSample(bpm: 100, percent: 54, timestamp: Date()))
        let lastReadingAt = Date()
        model.updateHeartRateAvailability(now: lastReadingAt.addingTimeInterval(2))
        #expect(!model.isHeartRateMissing)
        #expect(model.latestSample?.bpm == 100)

        model.updateHeartRateAvailability(now: lastReadingAt.addingTimeInterval(3.5))
        #expect(model.isHeartRateMissing)
        #expect(model.latestSample == nil)
        #expect(!audio.messages.contains(where: { $0.contains("No heart rate received") }))
        heartRate.onSample?(HeartRateSample(bpm: 0, percent: 0, timestamp: Date()))
        #expect(model.isHeartRateMissing)
        #expect(model.latestSample == nil)

        model.updateHeartRateAvailability(now: lastReadingAt.addingTimeInterval(11))
        #expect(audio.messages.contains(where: { $0.contains("No heart rate received") }))
        heartRate.onSample?(HeartRateSample(bpm: 110, percent: 60, timestamp: Date()))
        #expect(!model.isHeartRateMissing)
        #expect(model.latestSample?.bpm == 110)
    }

    @MainActor
    @Test(arguments: [true, false])
    func displayedCueUpdatesImmediatelyWithoutRoundingDrift(startInBPM: Bool) {
        let heartRate = BackgroundTestHeartRateService()
        let audio = BackgroundTestAudioCoach()
        let model = RunnerViewModel(heartRateService: heartRate,
                                    settingsStore: BackgroundTestSettingsStore(),
                                    sessionStore: BackgroundTestSessionStore(),
                                    sessionEngine: DefaultSessionEngine(), audioCoach: audio)
        defer {
            model.stopSession()
            model.disconnect()
        }
        var settings = model.settings
        settings.audioEnabled = true
        settings.displayMode = startInBPM ? .bpm : .percent
        settings.maxHeartRate = 185
        model.updateSettings(settings)
        model.selectSession(SessionTemplate(name: "Cue formatting", blocks: [
            SessionBlock(repetitions: 3, lowerTargetPercent: 61, upperTargetPercent: 73)
        ]))
        heartRate.onConnectionStateChanged?(.connected(HeartRateDevice(id: UUID(), name: "Test monitor")))
        model.startSession()
        func deliver(_ bpm: Int) {
            heartRate.onSample?(HeartRateSample(bpm: bpm, percent: 0, timestamp: Date()))
        }
        func verifyToggles(targetPercent: Int) {
            let originalMessage = model.lastMessage
            let originalCues = model.cues
            let spokenCount = audio.messages.count
            for _ in 0..<3 {
                model.toggleDisplayMode()
                let target = model.settings.displayMode == .bpm
                    ? "\(HeartRateConverter.bpm(from: targetPercent, maxHeartRate: 185)) BPM"
                    : "\(targetPercent)%"
                #expect(model.lastMessage.contains(target))
                #expect(model.cues == originalCues)
                #expect(audio.messages.count == spokenCount)
                model.toggleDisplayMode()
                #expect(model.lastMessage == originalMessage)
            }
        }
        deliver(150)
        deliver(150)
        #expect(model.cues == [.slowDownToStart(target: 61)])
        verifyToggles(targetPercent: 61)
        deliver(100)
        #expect(model.cues == [.speedUp(target: 73, repetition: 1, total: 3)])
        deliver(120)
        #expect(model.cues.isEmpty)
        verifyToggles(targetPercent: 73)
        deliver(150)
        #expect(model.cues == [.slowDown(target: 61, repetition: 1, total: 3)])
        verifyToggles(targetPercent: 61)
        let spokenCount = audio.messages.count
        var changed = model.settings
        changed.maxHeartRate = 200
        changed.displayMode = .bpm
        model.updateSettings(changed)
        #expect(model.lastMessage.contains("122 BPM"))
        #expect(audio.messages.count == spokenCount)
        deliver(100)
        #expect(model.cues == [.speedUp(target: 73, repetition: 2, total: 3)])
    }

    @MainActor
    @Test(arguments: [true, false])
    func startupIsSilentUntilSavedPreferencesAreLoaded(audioEnabled: Bool) async {
        let heartRate = BackgroundTestHeartRateService()
        let audio = BackgroundTestAudioCoach()
        let model = RunnerViewModel(heartRateService: heartRate,
                                    settingsStore: BackgroundTestSettingsStore(audioEnabled: audioEnabled),
                                    sessionStore: BackgroundTestSessionStore(sessions: BuiltinSessions.all),
                                    sessionEngine: DefaultSessionEngine(), audioCoach: audio)
        defer { model.disconnect() }
        #expect(!AppSettings.default.audioEnabled)
        #expect(!model.settings.audioEnabled)
        heartRate.onConnectionStateChanged?(.connected(HeartRateDevice(id: UUID(), name: "Test monitor")))
        heartRate.onSample?(HeartRateSample(bpm: 100, percent: 54, timestamp: Date()))
        #expect(audio.messages.isEmpty)
        await model.loadSettings()
        #expect(model.settings.audioEnabled == audioEnabled)
        #expect(model.currentSession.id == PyramidWorkout.flatFartlek.id)
        #expect(model.currentSession.notes.isEmpty)
        #expect(!model.currentSession.isPremium)
        #expect(model.currentSession.blocks.allSatisfy { $0.warmupRepetitions == 0 })
        #expect(audio.messages.isEmpty)
        heartRate.onSample?(HeartRateSample(bpm: 110, percent: 60, timestamp: Date()))
        #expect(audio.messages.count == (audioEnabled ? 1 : 0))
    }

    @MainActor
    @Test(arguments: [true, false])
    func missingDataWarnsWithoutRunningSession(audioEnabled: Bool) {
        let heartRate = BackgroundTestHeartRateService()
        let audio = BackgroundTestAudioCoach()
        let model = RunnerViewModel(heartRateService: heartRate,
                                    settingsStore: BackgroundTestSettingsStore(),
                                    sessionStore: BackgroundTestSessionStore(),
                                    sessionEngine: DefaultSessionEngine(), audioCoach: audio)
        defer { model.disconnect() }
        var settings = model.settings
        settings.audioEnabled = audioEnabled
        model.updateSettings(settings)
        let device = HeartRateDevice(id: UUID(), name: "Test watch")
        heartRate.onConnectionStateChanged?(.connected(device))
        heartRate.onSample?(HeartRateSample(bpm: 100, percent: 54, timestamp: Date()))
        let missingAt = Date().addingTimeInterval(11)
        model.updateHeartRateAvailability(now: missingAt)
        #expect(model.isHeartRateMissing)
        #expect(model.latestSample == nil)
        #expect(model.monitorStatus.contains("no heart rate received"))
        #expect(!model.isRunning)
        func warningCount() -> Int {
            audio.messages.filter { $0.contains("No heart rate received") }.count
        }
        #expect(warningCount() == (audioEnabled ? 1 : 0))
        model.updateHeartRateAvailability(now: missingAt.addingTimeInterval(1))
        #expect(warningCount() == (audioEnabled ? 1 : 0))
        model.updateHeartRateAvailability(now: missingAt.addingTimeInterval(10))
        #expect(warningCount() == (audioEnabled ? 2 : 0))
        heartRate.onSample?(HeartRateSample(bpm: 100, percent: 54, timestamp: Date()))
        #expect(!model.isHeartRateMissing)
        #expect(model.monitorStatus == "Connected to Test watch")
        model.updateHeartRateAvailability()
        #expect(warningCount() == (audioEnabled ? 2 : 0))
        model.disconnect()
        model.updateHeartRateAvailability(now: missingAt.addingTimeInterval(100))
        #expect(!model.isHeartRateMissing)
        #expect(warningCount() == (audioEnabled ? 2 : 0))
    }
}

@MainActor
private final class BackgroundTestHeartRateService: HeartRateService {
    var onConnectionStateChanged: ((HeartRateConnectionState) -> Void)?
    var onSample: ((HeartRateSample) -> Void)?
    var onDevicesChanged: (([HeartRateDevice]) -> Void)?
    var onSpecificationsChanged: ((UUID, HeartRateDeviceSpecifications) -> Void)?
    private(set) var connectionRequests: [HeartRateDevice] = []
    func startScan() {}
    func stopScan() {}
    func connect(to device: HeartRateDevice) { connectionRequests.append(device) }
    func disconnect() { onConnectionStateChanged?(.disconnected) }
    func checkForExistingConnection() {}
}

@MainActor
private final class BackgroundTestAudioCoach: AudioCoach {
    var messages: [String] = []
    var automaticPulseAttempts: [String] = []
    var isBusy = false
    var deactivationCount = 0
    func activate() {}
    func deactivate() { deactivationCount += 1 }
    func stop() {}
    func speak(_ message: String, settings: AppSettings) {
        if settings.audioEnabled { messages.append(message) }
    }
    func speakAutomaticPulse(_ message: String, settings: AppSettings) {
        guard settings.audioEnabled else { return }
        automaticPulseAttempts.append(message)
        if !isBusy { messages.append(message) }
    }
}

@MainActor
private final class BackgroundTestSessionEngine: SessionEngine {
    private let engine = DefaultSessionEngine()
    private(set) var consumeCount = 0

    func reset(session: SessionTemplate) {
        engine.reset(session: session)
    }

    func consume(sample: HeartRateSample, settings: AppSettings, now: Date) -> [SessionCue] {
        consumeCount += 1
        return engine.consume(sample: sample, settings: settings, now: now)
    }
}

private actor BackgroundTestSettingsStore: SettingsStore {
    private let audioEnabled: Bool

    init(audioEnabled: Bool = false) {
        self.audioEnabled = audioEnabled
    }

    func loadSettings() async -> AppSettings {
        let enabled = audioEnabled
        return await MainActor.run {
            var settings = AppSettings.default
            settings.audioEnabled = enabled
            return settings
        }
    }
    func saveSettings(_ settings: AppSettings) async {}
    func saveLastConnectedDevice(_ device: HeartRateDevice) async {}
    func loadLastConnectedDevice() async -> HeartRateDevice? { nil }
    func clearLastConnectedDevice() async {}
}

private actor BackgroundTestSessionStore: SessionStore {
    private let sessions: [SessionTemplate]

    init(sessions: [SessionTemplate] = []) {
        self.sessions = sessions
    }

    func loadSessions() async throws -> [SessionTemplate] { sessions }
    func saveSessions(_ sessions: [SessionTemplate]) async throws {}
}
