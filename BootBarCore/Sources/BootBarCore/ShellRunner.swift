import Foundation

public protocol ShellRunner: Sendable {
    @discardableResult
    func run(_ executable: String, _ arguments: [String]) async throws -> String
    func launchDetached(_ executable: String, _ arguments: [String]) throws
}

public struct ShellError: Error, Equatable, Sendable {
    public let command: String
    public let exitCode: Int32
    public let stderr: String

    public init(command: String, exitCode: Int32, stderr: String) {
        self.command = command
        self.exitCode = exitCode
        self.stderr = stderr
    }
}

public struct ProcessShellRunner: ShellRunner {
    public init() {}

    @discardableResult
    public func run(_ executable: String, _ arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                continuation.resume(with: Result { try Self.runSync(executable, arguments) })
            }
        }
    }

    public func launchDetached(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    private static func runSync(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ShellError(
                command: ([executable] + arguments).joined(separator: " "),
                exitCode: process.terminationStatus,
                stderr: String(decoding: errData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return String(decoding: outData, as: UTF8.self)
    }
}
