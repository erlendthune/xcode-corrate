import Foundation

@MainActor
protocol AudioCoach: AnyObject {
    /// Activates the shared audio session so speech keeps working while the app is backgrounded / screen is locked.
    func activate()
    /// Deactivates the shared audio session once coaching is no longer needed.
    func deactivate()
    func speak(_ message: String, settings: AppSettings)
    func stop()
}
