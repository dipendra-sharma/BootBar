import Foundation
@testable import BootBarCore

final class MockShellRunner: ShellRunner, @unchecked Sendable {
    private let lock = NSLock()
    private var storedResponses: [String: Result<String, ShellError>] = [:]
    private var storedDelays: [String: Duration] = [:]
    private var storedCommands: [String] = []
    private var liveByCommand: [String: Int] = [:]
    private var peakByCommand: [String: Int] = [:]

    var responses: [String: Result<String, ShellError>] {
        get { lock.withLock { storedResponses } }
        set { lock.withLock { storedResponses = newValue } }
    }

    var delays: [String: Duration] {
        get { lock.withLock { storedDelays } }
        set { lock.withLock { storedDelays = newValue } }
    }

    var commands: [String] {
        lock.withLock { storedCommands }
    }

    func maxConcurrency(of command: String) -> Int {
        lock.withLock { peakByCommand[command] ?? 0 }
    }

    @discardableResult
    func run(_ executable: String, _ arguments: [String]) async throws -> String {
        let key = ([executable] + arguments).joined(separator: " ")
        let (response, delay) = lock.withLock {
            storedCommands.append(key)
            let live = (liveByCommand[key] ?? 0) + 1
            liveByCommand[key] = live
            peakByCommand[key] = max(peakByCommand[key] ?? 0, live)
            return (storedResponses[key], storedDelays[key])
        }
        if let delay {
            try? await Task.sleep(for: delay)
        }
        lock.withLock { liveByCommand[key] = (liveByCommand[key] ?? 1) - 1 }
        guard let response else { return "" }
        return try response.get()
    }

    func launchDetached(_ executable: String, _ arguments: [String], failureWindow: Duration) async throws {
        let key = "detached " + ([executable] + arguments).joined(separator: " ")
        let response = lock.withLock {
            storedCommands.append(key)
            return storedResponses[key]
        }
        _ = try response?.get()
    }
}
