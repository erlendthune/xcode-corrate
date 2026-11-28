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

    /// Comparisons and emitted cue targets use percentages of maximum HR.
    /// Formatting into BPM or percent belongs to the presentation layer.
    func consume(sample: HeartRateSample, settings: AppSettings, now: Date) -> [SessionCue] {
        guard let session, blockIndex < session.blocks.count else { return [] }
        let block = session.blocks[blockIndex]

        // Changing display mode must not change workout targets or progression.
        let samplePercent = sample.percent
        let lowerPercent = block.lowerTargetPercent
        let upperPercent = block.upperTargetPercent

        var cues: [SessionCue] = []
        let warmupMinutes = Int(ceil(Double(session.warmupDurationSeconds) / 60))

        switch phase {
        case .started:
            if warmupStartedAt == nil {
                warmupStartedAt = now
            }
            if session.warmupDurationSeconds > 0 {
                lastSpokenWarmupMinute = warmupMinutes
                phase = .warmup
                cues.append(.warmupStarted(minutes: warmupMinutes))
            } else {
                phase = .warmupFinished
            }

        case .warmup:
            let elapsed = now.timeIntervalSince(warmupStartedAt ?? now)
            let totalWarmupSeconds = Double(session.warmupDurationSeconds)
            let remainingMinutes = Int(ceil((totalWarmupSeconds - elapsed) / 60))
            if elapsed >= totalWarmupSeconds {
                phase = .warmupFinished
            } else if remainingMinutes < (lastSpokenWarmupMinute ?? warmupMinutes) {
                lastSpokenWarmupMinute = remainingMinutes
                cues.append(.warmupMinutesRemaining(remainingMinutes))
            }

        case .warmupFinished:
            if samplePercent > lowerPercent {
                phase = .slowdownToStart
                cues.append(.slowDownToStart(target: lowerPercent))
            } else {
                phase = .speedup
                cues.append(.speedUp(target: upperPercent, repetition: repetition, total: block.repetitions))
            }

        case .slowdownToStart:
            if samplePercent <= lowerPercent {
                phase = .speedup
                cues.append(.speedUp(target: upperPercent, repetition: repetition, total: block.repetitions))
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
                        phase = .speedup
                        cues.append(.blockStarted(blockIndex: blockIndex, repetition: repetition))
                        cues.append(.speedUp(target: nextBlock.upperTargetPercent, repetition: repetition, total: nextBlock.repetitions))
                    }
                } else {
                    repetition += 1
                    phase = .speedup
                    cues.append(.speedUp(target: upperPercent, repetition: repetition, total: block.repetitions))
                }
            }

        case .speedup:
            if samplePercent >= upperPercent {
                cues.append(.slowDown(target: lowerPercent, repetition: repetition, total: block.repetitions))
                phase = .slowdown
            }

        case .finished:
            break
        }

        return cues
    }

}
