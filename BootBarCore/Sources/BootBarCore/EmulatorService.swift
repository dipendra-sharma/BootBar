import Foundation

public struct EmulatorService: Sendable {
    private let runner: any ShellRunner
    private let sdk: AndroidSDK
    private let avdHome: String
    private let consoleTimeout: Duration
    private let readFile: @Sendable (String) -> String?

    public init(runner: any ShellRunner, sdk: AndroidSDK,
                avdHome: String = NSHomeDirectory() + "/.android/avd",
                consoleTimeout: Duration = .seconds(3),
                readFile: @escaping @Sendable (String) -> String? = { try? String(contentsOfFile: $0, encoding: .utf8) }) {
        self.runner = runner
        self.sdk = sdk
        self.avdHome = avdHome
        self.consoleTimeout = consoleTimeout
        self.readFile = readFile
    }

    public func listDevices() async throws -> [Device] {
        let names = AvdParser.parseAvdNames(try await runner.run(sdk.emulatorPath, ["-list-avds"]))
        let present = try await presentAvds()
        return names.map { name in
            let info = present[name]
            return Device(id: name, name: name, platform: .android, osVersion: osVersion(for: name),
                          state: state(for: info), serial: info?.serial)
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

    private func state(for info: (serial: String, online: Bool)?) -> DeviceState {
        guard let info else { return .stopped }
        return info.online ? .running : .booting
    }

    private func presentAvds() async throws -> [String: (serial: String, online: Bool)] {
        let entries = AvdParser.parseEmulatorDevices(try await runner.run(sdk.adbPath, ["devices"]))
        let resolved = await withTaskGroup(of: (serial: String, online: Bool, name: String?).self) { group in
            for entry in entries {
                group.addTask { (entry.serial, entry.online, await consoleAvdName(for: entry.serial)) }
            }
            return await group.reduce(into: []) { $0.append($1) }
        }
        return resolved.reduce(into: [:]) { map, entry in
            if let name = entry.name { map[name] = (entry.serial, entry.online) }
        }
    }

    private func consoleAvdName(for serial: String) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask {
                let output = try? await runner.run(sdk.adbPath, ["-s", serial, "emu", "avd", "name"])
                return output.flatMap(AvdParser.parseConsoleAvdName)
            }
            group.addTask {
                try? await Task.sleep(for: consoleTimeout)
                return nil
            }
            defer { group.cancelAll() }
            return await group.next() ?? nil
        }
    }

    private func osVersion(for name: String) -> String {
        guard let ini = readFile("\(avdHome)/\(name).avd/config.ini"),
              let api = AvdParser.parseApiLevel(configIni: ini) else { return "Android" }
        return "API \(api)"
    }
}
