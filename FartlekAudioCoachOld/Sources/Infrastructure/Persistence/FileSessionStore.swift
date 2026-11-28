import Foundation

final class FileSessionStore: SessionStore {
    private let fileName = "sessions.json"

    func loadSessions() throws -> [SessionTemplate] {
        let url = try sessionsURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return BuiltinSessions.all
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([SessionTemplate].self, from: data)
    }

    func saveSessions(_ sessions: [SessionTemplate]) throws {
        let data = try JSONEncoder().encode(sessions)
        let url = try sessionsURL()
        try data.write(to: url, options: .atomic)
    }

    private func sessionsURL() throws -> URL {
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return docs.appendingPathComponent(fileName)
    }
}

enum BuiltinSessions {
    // Free: basic flat fartlek (warmup + N iterations, one lower/upper zone).
    static let flatFartlek = SessionTemplate(
        name: "Flat Fartlek",
        notes: "A straightforward session: warm up, then repeat intervals between your lower and upper heart rate targets.",
        blocks: [
            SessionBlock(warmupRepetitions: 2, repetitions: 8, lowerTargetPercent: 70, upperTargetPercent: 80)
        ],
        isBuiltin: true,
        isPremium: false
    )

    // Premium: multi-block pyramid session.
    static let pyramid = SessionTemplate(
        name: "Pyramid 6-3-1-3-6",
        notes: "Escalate and descend through three intensity zones. Six easy intervals, then three medium, one hard peak, then back down.",
        blocks: [
            SessionBlock(repetitions: 6, lowerTargetPercent: 70, upperTargetPercent: 80),
            SessionBlock(repetitions: 3, lowerTargetPercent: 75, upperTargetPercent: 85),
            SessionBlock(repetitions: 1, lowerTargetPercent: 85, upperTargetPercent: 95),
            SessionBlock(repetitions: 3, lowerTargetPercent: 75, upperTargetPercent: 85),
            SessionBlock(repetitions: 6, lowerTargetPercent: 70, upperTargetPercent: 80)
        ],
        isBuiltin: true,
        isPremium: true
    )

    static let all: [SessionTemplate] = [flatFartlek, pyramid]
}
