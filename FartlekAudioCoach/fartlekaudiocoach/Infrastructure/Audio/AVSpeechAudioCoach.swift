import AVFoundation
import Combine
import Foundation

@MainActor
final class AVSpeechAudioCoach: NSObject, AudioCoach, AVSpeechSynthesizerDelegate {
    private var synthesizer = AVSpeechSynthesizer()
    private var observers = Set<AnyCancellable>()
    private var isInterrupted = false
    private var coachingActive = false
    private var deactivateWhenFinished = false

    override init() {
        super.init()
        synthesizer.delegate = self
        // Use our configured playback session for locked-screen speech.
        synthesizer.usesApplicationAudioSession = true
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                Task { @MainActor [weak self] in
                    self?.handleInterruption(type: type, options: options)
                }
            }
            .store(in: &observers)
        NotificationCenter.default.publisher(for: AVAudioSession.mediaServicesWereResetNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.synthesizer = AVSpeechSynthesizer()
                    self.synthesizer.delegate = self
                    self.synthesizer.usesApplicationAudioSession = true
                    self.isInterrupted = false
                    self.deactivateWhenFinished = false
                    if self.coachingActive { self.configureAudioSession() }
                    print("🔊 Audio services reset; speech synthesizer rebuilt")
                }
            }
            .store(in: &observers)
    }

    /// Allows background speech; Bluetooth notifications provide execution between cues.
    func activate() {
        coachingActive = true
        deactivateWhenFinished = false
        configureAudioSession()
    }

    private func configureAudioSession() {
        guard !isInterrupted else { return }
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: .mixWithOthers)
            try audioSession.setActive(true)
        } catch {
            print("🔊 Audio session activation failed: \(error.localizedDescription)")
        }
    }

    func deactivate() {
        coachingActive = false
        // stopSession queues its final cue immediately before calling deactivate.
        if synthesizer.isSpeaking || synthesizer.isPaused {
            deactivateWhenFinished = true
            return
        }
        deactivateAudioSession()
    }

    private func deactivateAudioSession() {
        deactivateWhenFinished = false
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("🔊 Audio session deactivation failed: \(error.localizedDescription)")
        }
    }

    func speak(_ message: String, settings: AppSettings) {
        guard settings.audioEnabled, !isInterrupted else { return }
        configureAudioSession()

        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = Float(settings.voiceRate)
        print("🔊 Speaking: '\(message)' | Rate: \(utterance.rate) | Min: \(AVSpeechUtteranceMinimumSpeechRate) | Max: \(AVSpeechUtteranceMaximumSpeechRate)")
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func handleInterruption(type: UInt?, options: UInt) {
        guard let type, let interruption = AVAudioSession.InterruptionType(rawValue: type) else { return }
        switch interruption {
        case .began:
            isInterrupted = true
            // Drop stale cues instead of replaying workout instructions after a call.
            synthesizer.stopSpeaking(at: .immediate)
            print("🔊 Audio interrupted")
        case .ended:
            isInterrupted = false
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume)
            if coachingActive && shouldResume { configureAudioSession() }
            print("🔊 Audio interruption ended; should resume: \(shouldResume)")
        @unknown default:
            break
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                      didPause utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, !self.isInterrupted, self.synthesizer.isPaused else { return }
            self.synthesizer.continueSpeaking()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                      didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.deactivateWhenFinished && !self.synthesizer.isSpeaking && !self.synthesizer.isPaused {
                self.deactivateAudioSession()
            }
        }
    }
}
