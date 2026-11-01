import Foundation

enum SessionCue: Equatable {
    case blockStarted(blockIndex: Int, repetition: Int)
    case blockCompleted(blockIndex: Int)
    case sessionCompleted
    case tooLow(target: Int)    // target expressed in current display mode
    case tooHigh(target: Int)   // target expressed in current display mode
}

protocol SessionEngine {
    func reset(session: SessionTemplate)
    func consume(sample: HeartRateSample, settings: AppSettings, now: Date) -> [SessionCue]
}
