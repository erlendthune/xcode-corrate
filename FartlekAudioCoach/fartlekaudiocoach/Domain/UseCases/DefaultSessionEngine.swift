import Foundation

/// Ported from the well-tested HRMFartlekState machine (HRMViewController.m) in the Corrate app.
private enum FartlekPhase {
    case started
    case warmup
    case warmupFinished
    case slowdownToStart
    case slowdown
    case speedup
    case finished
}

final class DefaultSessionEngine: SessionEngine {
    private var session: SessionTemplate?
    private var phase: FartlekPhase = .started
    private var blockIndex = 0
    private var repetition = 1
    private var warmupStartedAt: Date?
    private var lastSpokenWarmupMinute: Int?

    func reset(session: SessionTemplate) {
        self.session = session
        phase = .started
        blockIndex = 0
        repetition = 1
        warmupStartedAt = nil
        lastSpokenWarmupMinute = nil
    }

    /// Targets are stored as percent. When display mode is BPM, both the sample
    /// and displayed target are converted using the user's max heart rate.
    func consume(sample: HeartRateSample, settings: AppSettings, now: Date) -> [SessionCue] {
        guard let session, blockIndex < session.blocks.count else { return [] }
        let block = session.blocks[blockIndex]

        // Always compare using percent internally; convert target to BPM for cue display if needed.
        let samplePercent = sample.percent
        let lowerPercent = block.lowerTargetPercent
        let upperPercent = block.upperTargetPercent
        let displayedLower = displayedValue(forPercent: lowerPercent, settings: settings)
        let displayedUpper = displayedValue(forPercent: upperPercent, settings: settings)

        var cues: [SessionCue] = []

        switch phase {
        case .started:
            if warmupStartedAt == nil {
                warmupStartedAt = now
            }
            if session.warmupMinutes > 0 {
                lastSpokenWarmupMinute = session.warmupMinutes
                phase = .warmup
                cues.append(.warmupStarted(minutes: session.warmupMinutes))
            } else {
                phase = .warmupFinished
            }

        case .warmup:
            let elapsed = now.timeIntervalSince(warmupStartedAt ?? now)
            let totalWarmupSeconds = Double(session.warmupMinutes * 60)
            let remainingMinutes = Int(ceil((totalWarmupSeconds - elapsed) / 60))
            if elapsed >= totalWarmupSeconds {
                phase = .warmupFinished
            } else if remainingMinutes < (lastSpokenWarmupMinute ?? session.warmupMinutes) {
                lastSpokenWarmupMinute = remainingMinutes
                cues.append(.warmupMinutesRemaining(remainingMinutes))
            }

        case .warmupFinished:
            if samplePercent > lowerPercent {
                phase = .slowdownToStart
                cues.append(.slowDownToStart(target: displayedLower))
            } else {
                phase = .speedup
                cues.append(.speedUp(target: displayedUpper, repetition: repetition, total: block.repetitions))
            }

        case .slowdownToStart:
            if samplePercent <= lowerPercent {
                phase = .speedup
                cues.append(.speedUp(target: displayedUpper, repetition: repetition, total: block.repetitions))
            }

        case .slowdown:
            if samplePercent <= lowerPercent {
                if repetition >= block.repetitions {
                    cues.append(.blockCompleted(blockIndex: blockIndex))
                    blockIndex += 1
                    repetition = 1
                    if blockIndex >= session.blocks.count {
                        phase = .finished
                        cues.append(.sessionCompleted)
                    } else {
                        let nextBlock = session.blocks[blockIndex]
                        let nextUpper = displayedValue(forPercent: nextBlock.upperTargetPercent, settings: settings)
                        phase = .speedup
                        cues.append(.blockStarted(blockIndex: blockIndex, repetition: repetition))
                        cues.append(.speedUp(target: nextUpper, repetition: repetition, total: nextBlock.repetitions))
                    }
                } else {
                    repetition += 1
                    phase = .speedup
                    cues.append(.speedUp(target: displayedUpper, repetition: repetition, total: block.repetitions))
                }
            }

        case .speedup:
            if samplePercent >= upperPercent {
                cues.append(.slowDown(target: displayedLower, repetition: repetition, total: block.repetitions))
                phase = .slowdown
            }

        case .finished:
            break
        }

        return cues
    }

    private func displayedValue(forPercent percent: Int, settings: AppSettings) -> Int {
        settings.displayMode == .bpm
            ? HeartRateConverter.bpm(from: percent, maxHeartRate: settings.maxHeartRate)
            : percent
    }
}
