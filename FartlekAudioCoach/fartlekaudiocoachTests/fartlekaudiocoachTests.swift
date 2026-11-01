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
        let model = RunnerViewModel(heartRateService: heartRate,
                                    settingsStore: BackgroundTestSettingsStore(),
                                    sessionStore: BackgroundTestSessionStore(),
                                    sessionEngine: DefaultSessionEngine(), audioCoach: audio)
        defer { model.disconnect() }
        let device = HeartRateDevice(id: UUID(), name: "Test monitor")
        heartRate.onConnectionStateChanged?(.connected(device))
        let start = Date()
        let interval = AppSettings.default.heartRateSpeakIntervalSeconds
        func deliver(after seconds: Int) {
            heartRate.onSample?(HeartRateSample(bpm: 100, percent: 54,
                                               timestamp: start.addingTimeInterval(Double(seconds))))
        }
        // No loadSettings(), so no announcement/countdown timers are running.
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
            target: AppSettings.default.displayMode == .bpm
                ? HeartRateConverter.bpm(from: 80, maxHeartRate: AppSettings.default.maxHeartRate) : 80,
            repetition: 1, total: 1
        )])
        #expect(audio.messages.contains(model.lastMessage))
    }

    @MainActor
    @Test func speechIntervalChangesApplyImmediatelyAndZeroSpeaksEverySample() {
        let heartRate = BackgroundTestHeartRateService()
        let audio = BackgroundTestAudioCoach()
        let model = RunnerViewModel(heartRateService: heartRate,
                                    settingsStore: BackgroundTestSettingsStore(),
                                    sessionStore: BackgroundTestSessionStore(),
                                    sessionEngine: DefaultSessionEngine(), audioCoach: audio)
        defer { model.disconnect() }
        heartRate.onConnectionStateChanged?(.connected(HeartRateDevice(id: UUID(), name: "Test monitor")))
        var settings = model.settings
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
        let changedAt = Date()
        // Synchronous delivery does not allow any foreground timers to fire.
        deliver(at: changedAt.addingTimeInterval(4))
        #expect(audio.messages.count == 1)
        deliver(at: changedAt.addingTimeInterval(5))
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
        deliver(at: resumedAt.addingTimeInterval(5))
        #expect(audio.messages.count == 5)
    }

}

@MainActor
private final class BackgroundTestHeartRateService: HeartRateService {
    var onConnectionStateChanged: ((HeartRateConnectionState) -> Void)?
    var onSample: ((HeartRateSample) -> Void)?
    var onDevicesChanged: (([HeartRateDevice]) -> Void)?
    func startScan() {}
    func stopScan() {}
    func connect(to device: HeartRateDevice) {}
    func disconnect() { onConnectionStateChanged?(.disconnected) }
    func checkForExistingConnection() {}
}

@MainActor
private final class BackgroundTestAudioCoach: AudioCoach {
    var messages: [String] = []
    func activate() {}
    func deactivate() {}
    func stop() {}
    func speak(_ message: String, settings: AppSettings) {
        if settings.audioEnabled { messages.append(message) }
    }
}

private actor BackgroundTestSettingsStore: SettingsStore {
    func loadSettings() async -> AppSettings {
        await MainActor.run { AppSettings.default }
    }
    func saveSettings(_ settings: AppSettings) async {}
    func saveLastConnectedDevice(_ device: HeartRateDevice) async {}
    func loadLastConnectedDevice() async -> HeartRateDevice? { nil }
    func clearLastConnectedDevice() async {}
}

private actor BackgroundTestSessionStore: SessionStore {
    func loadSessions() async throws -> [SessionTemplate] { [] }
    func saveSessions(_ sessions: [SessionTemplate]) async throws {}
}
