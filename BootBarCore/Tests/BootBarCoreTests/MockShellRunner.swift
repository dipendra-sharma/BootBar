import Foundation
@testable import BootBarCore

final class MockShellRunner: ShellRunner, @unchecked Sendable {
    private let lock = NSLock()
    private var storedResponses: [String: Result<String, ShellError>] = [:]
    private var storedDelays: [String: Duration] = [:]
    private var storedCommands: [String] = []

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

    @discardableResult
    func run(_ executable: String, _ arguments: [String]) async throws -> String {
        let key = ([executable] + arguments).joined(separator: " ")
        let (response, delay) = lock.withLock {
            storedCommands.append(key)
            return (storedResponses[key], storedDelays[key])
        }
        if let delay {
            try? await Task.sleep(for: delay)
        }
        guard let response else { return "" }
        return try response.get()
    }

    func launchDetached(_ executable: String, _ arguments: [String]) throws {
        lock.withLock {
            storedCommands.append("detached " + ([executable] + arguments).joined(separator: " "))
        }
    }
}
