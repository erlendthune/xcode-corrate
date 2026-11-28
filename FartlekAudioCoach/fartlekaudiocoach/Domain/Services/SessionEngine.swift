import Foundation

enum SessionCue: Equatable {
    case warmupStarted(minutes: Int)
    case warmupMinutesRemaining(Int)
    case blockStarted(blockIndex: Int, repetition: Int)
    case blockCompleted(blockIndex: Int)
    case sessionCompleted
    // Targets remain percentages of maximum HR; views and speech format them.
    case slowDownToStart(target: Int)
    case slowDown(target: Int, repetition: Int, total: Int)
    case speedUp(target: Int, repetition: Int, total: Int)
}

protocol SessionEngine {
    func reset(session: SessionTemplate)
    func consume(sample: HeartRateSample, settings: AppSettings, now: Date) -> [SessionCue]
}
