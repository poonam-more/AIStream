import Foundation

/// In-memory settings with simulated persistence delay.
final class MockSettingsService: SettingsServiceProtocol, @unchecked Sendable {

    private var settings = AppSettings.default
    private let lock = NSLock()

    func fetchSettings() async throws -> AppSettings {
        try await MockDelay.simulateShort()
        lock.lock()
        defer { lock.unlock() }
        return settings
    }

    func saveSettings(_ settings: AppSettings) async throws {
        try await MockDelay.simulateShort()
        lock.lock()
        self.settings = settings
        lock.unlock()
    }
}
