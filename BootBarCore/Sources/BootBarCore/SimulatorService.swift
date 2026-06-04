public struct SimulatorService: Sendable {
    private let runner: any ShellRunner
    private let xcrun = "/usr/bin/xcrun"

    public init(runner: any ShellRunner) {
        self.runner = runner
    }

    public func listDevices() async throws -> [Device] {
        let json = try await runner.run(xcrun, ["simctl", "list", "devices", "--json"])
        return try SimctlParser.parseDevices(json: json)
    }

    public func boot(_ udid: String) async throws {
        try await runner.run(xcrun, ["simctl", "boot", udid])
        try await runner.run("/usr/bin/open", ["-a", "Simulator"])
    }

    public func shutdown(_ udid: String) async throws {
        try await shutdownDevice(udid)
        await quitSimulatorAppIfIdle()
    }

    public func coldBoot(_ device: Device) async throws {
        if device.state == .running {
            try await shutdownDevice(device.id)
        }
        try await boot(device.id)
    }

    public func erase(_ device: Device) async throws {
        if device.state == .running {
            try await shutdownDevice(device.id)
        }
        try await runner.run(xcrun, ["simctl", "erase", device.id])
        await quitSimulatorAppIfIdle()
    }

    private func shutdownDevice(_ udid: String) async throws {
        try await runner.run(xcrun, ["simctl", "shutdown", udid])
    }

    private func quitSimulatorAppIfIdle() async {
        guard let devices = try? await listDevices(),
              devices.allSatisfy({ $0.state == .stopped }) else { return }
        try? await runner.run("/usr/bin/pkill", ["-x", "Simulator"])
    }
}
