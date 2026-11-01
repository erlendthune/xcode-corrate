import Foundation

enum SessionCue: Equatable {
    case warmupStarted(minutes: Int)
    case warmupMinutesRemaining(Int)
    case blockStarted(blockIndex: Int, repetition: Int)
    case blockCompleted(blockIndex: Int)
    case sessionCompleted
    case slowDownToStart(target: Int)                        // target expressed in current display mode
    case slowDown(target: Int, repetition: Int, total: Int)  // target expressed in current display mode
    case speedUp(target: Int, repetition: Int, total: Int)   // target expressed in current display mode
}

protocol SessionEngine {
    func reset(session: SessionTemplate)
    func consume(sample: HeartRateSample, settings: AppSettings, now: Date) -> [SessionCue]
}
