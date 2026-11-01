import Foundation

final class DefaultSessionEngine: SessionEngine {
    private let confirmationBeatCount = 2
    private let transitionCooldown: TimeInterval = 3

    private var session: SessionTemplate?
    private var blockIndex = 0
    private var repetition = 1
    private var highHitCount = 0
    private var lowHitCount = 0
    private var lastTransitionAt: Date?
    private var inHighPhase = true

    func reset(session: SessionTemplate) {
        self.session = session
        blockIndex = 0
        repetition = 1
        highHitCount = 0
        lowHitCount = 0
        lastTransitionAt = nil
        inHighPhase = true
    }

    /// Targets are stored as percent. When display mode is BPM, both the sample
    /// and displayed target are converted using the user's max heart rate.
    func consume(sample: HeartRateSample, settings: AppSettings, now: Date) -> [SessionCue] {
        guard let session, blockIndex < session.blocks.count else { return [] }
        let block = session.blocks[blockIndex]

        if let lastTransitionAt, now.timeIntervalSince(lastTransitionAt) < transitionCooldown {
            return []
        }

        // Always compare using percent internally; convert target to BPM for cue display if needed.
        let samplePercent = sample.percent
        let lowerPercent = block.lowerTargetPercent
        let upperPercent = block.upperTargetPercent

        // Displayed target follows user's display mode setting.
        let displayedLower = settings.displayMode == .bpm
            ? HeartRateConverter.bpm(from: lowerPercent, maxHeartRate: settings.maxHeartRate)
            : lowerPercent
        let displayedUpper = settings.displayMode == .bpm
            ? HeartRateConverter.bpm(from: upperPercent, maxHeartRate: settings.maxHeartRate)
            : upperPercent

        var cues: [SessionCue] = []

        if inHighPhase {
            if samplePercent >= upperPercent {
                highHitCount += 1
                if highHitCount >= confirmationBeatCount {
                    highHitCount = 0
                    lowHitCount = 0
                    inHighPhase = false
                    lastTransitionAt = now
                    cues.append(.tooHigh(target: displayedUpper))
                }
            } else {
                highHitCount = 0
            }
        } else {
            if samplePercent <= lowerPercent {
                lowHitCount += 1
                if lowHitCount >= confirmationBeatCount {
                    lowHitCount = 0
                    highHitCount = 0
                    inHighPhase = true
                    lastTransitionAt = now
                    cues.append(.tooLow(target: displayedLower))

                    if repetition >= block.repetitions {
                        cues.append(.blockCompleted(blockIndex: blockIndex))
                        blockIndex += 1
                        repetition = 1
                        if blockIndex >= session.blocks.count {
                            cues.append(.sessionCompleted)
                        } else {
                            cues.append(.blockStarted(blockIndex: blockIndex, repetition: repetition))
                        }
                    } else {
                        repetition += 1
                        cues.append(.blockStarted(blockIndex: blockIndex, repetition: repetition))
                    }
                }
            } else {
                lowHitCount = 0
            }
        }

        return cues
    }
}
