import Foundation

protocol SessionStore {
    func loadSessions() throws -> [SessionTemplate]
    func saveSessions(_ sessions: [SessionTemplate]) throws
}
