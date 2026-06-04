import Foundation

public struct EmulatorService: Sendable {
    private let runner: any ShellRunner
    private let sdk: AndroidSDK
    private let avdHome: String
    private let readFile: @Sendable (String) -> String?

    public init(runner: any ShellRunner, sdk: AndroidSDK,
                avdHome: String = NSHomeDirectory() + "/.android/avd",
                readFile: @escaping @Sendable (String) -> String? = { try? String(contentsOfFile: $0, encoding: .utf8) }) {
        self.runner = runner
        self.sdk = sdk
        self.avdHome = avdHome
        self.readFile = readFile
    }

    public func listDevices() async throws -> [Device] {
        let names = AvdParser.parseAvdNames(try await runner.run(sdk.emulatorPath, ["-list-avds"]))
        let running = try await runningAvds()
        return names.map { name in
            Device(id: name, name: name, platform: .android, osVersion: osVersion(for: name),
                   state: running[name] != nil ? .running : .stopped, serial: running[name])
        }
    }

    public func start(_ name: String, extraArguments: [String] = []) throws {
        try runner.launchDetached(sdk.emulatorPath, ["-avd", name] + extraArguments)
    }

    public func stop(serial: String) async throws {
        try await runner.run(sdk.adbPath, ["-s", serial, "emu", "kill"])
    }

    public func coldBoot(_ device: Device) async throws {
        try await killIfRunning(device)
        try start(device.name, extraArguments: ["-no-snapshot-load"])
    }

    public func wipe(_ device: Device) async throws {
        try await killIfRunning(device)
        try start(device.name, extraArguments: ["-wipe-data"])
    }

    private func killIfRunning(_ device: Device) async throws {
        guard let serial = device.serial else { return }
        try await stop(serial: serial)
        try await Task.sleep(for: .seconds(2))
    }

    private func runningAvds() async throws -> [String: String] {
        let serials = AvdParser.parseEmulatorSerials(try await runner.run(sdk.adbPath, ["devices"]))
        var map: [String: String] = [:]
        for serial in serials {
            let output = try? await runner.run(sdk.adbPath, ["-s", serial, "emu", "avd", "name"])
            if let output, let name = AvdParser.parseConsoleAvdName(output) {
                map[name] = serial
            }
        }
        return map
    }

    private func osVersion(for name: String) -> String {
        guard let ini = readFile("\(avdHome)/\(name).avd/config.ini"),
              let api = AvdParser.parseApiLevel(configIni: ini) else { return "Android" }
        return "API \(api)"
    }
}
