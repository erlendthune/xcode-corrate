import Foundation

protocol SessionStore: Sendable {
    func loadSessions() async throws -> [SessionTemplate]
    func saveSessions(_ sessions: [SessionTemplate]) async throws
}
