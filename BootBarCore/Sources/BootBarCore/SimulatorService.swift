import Foundation

public struct SimulatorService: Sendable {
    private let runner: any ShellRunner
    private let hostLocator: SimulatorHostLocator
    private let terminateHosts: @Sendable (Set<String>) -> Void
    private let xcrun = "/usr/bin/xcrun"

    public init(runner: any ShellRunner,
                hostLocator: SimulatorHostLocator = SimulatorHostLocator(),
                terminateHosts: @escaping @Sendable (Set<String>) -> Void = SimulatorHost.terminateRunning) {
        self.runner = runner
        self.hostLocator = hostLocator
        self.terminateHosts = terminateHosts
    }

    public func listDevices() async throws -> [Device] {
        let json = try await runner.run(xcrun, ["simctl", "list", "devices", "--json"])
        return try SimctlParser.parseDevices(json: json)
    }

    public func boot(_ udid: String) async throws {
        try await run(["simctl", "boot", udid], acceptingStateOf: udid) { $0 != .stopped }
        await openSimulatorApp()
    }

    public func shutdown(_ udid: String) async throws {
        try await shutdownDevice(udid)
        await quitSimulatorAppIfIdle()
    }

    public func coldBoot(_ device: Device) async throws {
        if device.state != .stopped {
            try await shutdownDevice(device.id)
        }
        try await boot(device.id)
    }

    public func erase(_ device: Device) async throws {
        if device.state != .stopped {
            try await shutdownDevice(device.id)
        }
        try await runner.run(xcrun, ["simctl", "erase", device.id])
        await quitSimulatorAppIfIdle()
    }

    private func shutdownDevice(_ udid: String) async throws {
        try await run(["simctl", "shutdown", udid], acceptingStateOf: udid) { $0 == .stopped }
    }

    private func run(_ arguments: [String], acceptingStateOf udid: String,
                     when isAcceptable: (DeviceState) -> Bool) async throws {
        do {
            try await runner.run(xcrun, arguments)
        } catch let error as ShellError {
            guard let state = await currentState(of: udid), isAcceptable(state) else { throw error }
        }
    }

    private func currentState(of udid: String) async -> DeviceState? {
        (try? await listDevices())?.first { $0.id == udid }?.state
    }

    private func openSimulatorApp() async {
        guard let host = await simulatorHost() else { return }
        _ = try? await runner.run("/usr/bin/open", ["-a", host.bundlePath])
    }

    private func simulatorHost() async -> SimulatorHost? {
        guard let developerDirectory = try? await runner.run("/usr/bin/xcode-select", ["-p"])
            .trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        return hostLocator.locate(developerDirectory: developerDirectory)
    }

    private func quitSimulatorAppIfIdle() async {
        guard let json = try? await runner.run(xcrun, ["simctl", "list", "devices", "booted", "--json"]),
              let anyBooted = try? SimctlParser.hasBootedDevices(json: json),
              !anyBooted else { return }
        terminateHosts(SimulatorHost.bundleIdentifiers)
    }
}
