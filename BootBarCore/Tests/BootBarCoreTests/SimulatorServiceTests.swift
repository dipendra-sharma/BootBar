import Foundation
import Testing
@testable import BootBarCore

private let bootedList = "/usr/bin/xcrun simctl list devices booted --json"
private let developerDirectory = "/Xcode.app/Contents/Developer"
private let legacySimulatorApp = "/Xcode.app/Contents/Developer/Applications/Simulator.app"
private let deviceHubApp = "/Xcode.app/Contents/Applications/DeviceHub.app"
private let openSimulatorApp = "/usr/bin/open -a " + legacySimulatorApp
private let openDeviceHubApp = "/usr/bin/open -a " + deviceHubApp

final class TerminationRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedCalls: [Set<String>] = []

    var calls: [Set<String>] { lock.withLock { storedCalls } }

    func record(_ bundleIdentifiers: Set<String>) {
        lock.withLock { storedCalls.append(bundleIdentifiers) }
    }
}

private func makeService(nothingBooted: Bool = true,
                         installedApp: String? = legacySimulatorApp)
-> (SimulatorService, MockShellRunner, TerminationRecorder) {
    let runner = MockShellRunner()
    runner.responses["/usr/bin/xcode-select -p"] = .success(developerDirectory + "\n")
    if nothingBooted {
        runner.responses[bootedList] = .success(#"{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-5":[]}}"#)
    }
    let locator = SimulatorHostLocator { $0 == installedApp }
    let terminations = TerminationRecorder()
    let service = SimulatorService(runner: runner,
                                   hostLocator: locator,
                                   terminateHosts: { terminations.record($0) })
    return (service, runner, terminations)
}

private func runningDevice() -> Device {
    Device(id: "UDID-1", name: "iPhone 16 Pro", platform: .ios, osVersion: "iOS 18.5", state: .running)
}

private func stoppedDevice() -> Device {
    Device(id: "UDID-1", name: "iPhone 16 Pro", platform: .ios, osVersion: "iOS 18.5", state: .stopped)
}

private func bootingDevice() -> Device {
    Device(id: "UDID-1", name: "iPhone 16 Pro", platform: .ios, osVersion: "iOS 18.5", state: .booting)
}

@Test func listDevicesIssuesSimctlList() async throws {
    let (service, runner, _) = makeService()
    runner.responses["/usr/bin/xcrun simctl list devices --json"] = .success(#"{"devices":{}}"#)
    let devices = try await service.listDevices()
    #expect(devices.isEmpty)
    #expect(runner.commands == ["/usr/bin/xcrun simctl list devices --json"])
}

@Test func bootOpensSimulatorAppFromTheActiveDeveloperDirectory() async throws {
    let (service, runner, _) = makeService()
    try await service.boot("UDID-1")
    #expect(runner.commands == [
        "/usr/bin/xcrun simctl boot UDID-1",
        "/usr/bin/xcode-select -p",
        openSimulatorApp
    ])
}

@Test func bootOpensDeviceHubWhenXcodeShipsNoSimulatorApp() async throws {
    let (service, runner, _) = makeService(installedApp: deviceHubApp)
    try await service.boot("UDID-1")
    #expect(runner.commands == [
        "/usr/bin/xcrun simctl boot UDID-1",
        "/usr/bin/xcode-select -p",
        openDeviceHubApp
    ])
}

@Test func bootSucceedsWhenNoHostAppIsInstalled() async throws {
    let (service, runner, _) = makeService(installedApp: nil)
    try await service.boot("UDID-1")
    #expect(runner.commands == [
        "/usr/bin/xcrun simctl boot UDID-1",
        "/usr/bin/xcode-select -p"
    ])
}

@Test func bootSucceedsWhenSimulatorAppCannotBeOpened() async throws {
    let (service, runner, _) = makeService()
    runner.responses["/usr/bin/xcode-select -p"] =
        .failure(ShellError(command: "xcode-select", exitCode: 1, stderr: "no developer dir"))
    try await service.boot("UDID-1")
    #expect(runner.commands.contains("/usr/bin/xcrun simctl boot UDID-1"))
}

@Test func bootTreatsAlreadyBootedDeviceAsSuccess() async throws {
    let (service, runner, _) = makeService()
    runner.responses["/usr/bin/xcrun simctl boot UDID-1"] =
        .failure(ShellError(command: "boot", exitCode: 149, stderr: "current state: Booted"))
    runner.responses["/usr/bin/xcrun simctl list devices --json"] = .success(
        #"{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-5":[{"udid":"UDID-1","name":"iPhone","state":"Booted","isAvailable":true}]}}"#)
    try await service.boot("UDID-1")
    #expect(runner.commands.contains(openSimulatorApp))
}

@Test func bootRethrowsWhenDeviceDidNotActuallyBoot() async {
    let (service, runner, _) = makeService()
    runner.responses["/usr/bin/xcrun simctl boot UDID-1"] =
        .failure(ShellError(command: "boot", exitCode: 149, stderr: "device not found"))
    runner.responses["/usr/bin/xcrun simctl list devices --json"] = .success(#"{"devices":{}}"#)
    await #expect(throws: ShellError.self) {
        try await service.boot("UDID-1")
    }
}

@Test func shutdownQuitsSimulatorAppWhenNothingRemainsBooted() async throws {
    let (service, runner, terminations) = makeService()
    try await service.shutdown("UDID-1")
    #expect(runner.commands == [
        "/usr/bin/xcrun simctl shutdown UDID-1",
        bootedList
    ])
    #expect(terminations.calls == [SimulatorHost.bundleIdentifiers])
}

@Test func shutdownQuitsBothLegacyAndCurrentHostApps() async throws {
    let (service, _, terminations) = makeService()
    try await service.shutdown("UDID-1")
    #expect(terminations.calls.first?.contains("com.apple.iphonesimulator") == true)
    #expect(terminations.calls.first?.contains("com.apple.dt.Devices") == true)
}

@Test func shutdownKeepsSimulatorAppWhenAnotherDeviceBooted() async throws {
    let (service, runner, terminations) = makeService(nothingBooted: false)
    runner.responses[bootedList] = .success(
        #"{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-5":[{"udid":"B","name":"iPad","state":"Booted","isAvailable":true}]}}"#)
    try await service.shutdown("UDID-1")
    #expect(runner.commands == ["/usr/bin/xcrun simctl shutdown UDID-1", bootedList])
    #expect(terminations.calls.isEmpty)
}

@Test func shutdownKeepsSimulatorAppWhenOnlyANonIOSDeviceBooted() async throws {
    let (service, runner, terminations) = makeService(nothingBooted: false)
    runner.responses[bootedList] = .success(
        #"{"devices":{"com.apple.CoreSimulator.SimRuntime.watchOS-11-5":[{"udid":"W","name":"Watch","state":"Booted","isAvailable":true}]}}"#)
    try await service.shutdown("UDID-1")
    #expect(terminations.calls.isEmpty)
}

@Test func coldBootShutsDownRunningDeviceFirst() async throws {
    let (service, runner, _) = makeService()
    try await service.coldBoot(runningDevice())
    #expect(runner.commands == [
        "/usr/bin/xcrun simctl shutdown UDID-1",
        "/usr/bin/xcrun simctl boot UDID-1",
        "/usr/bin/xcode-select -p",
        openSimulatorApp
    ])
}

@Test func coldBootShutsDownBootingDeviceFirst() async throws {
    let (service, runner, _) = makeService()
    try await service.coldBoot(bootingDevice())
    #expect(runner.commands.first == "/usr/bin/xcrun simctl shutdown UDID-1")
}

@Test func coldBootSkipsShutdownWhenStopped() async throws {
    let (service, runner, _) = makeService()
    try await service.coldBoot(stoppedDevice())
    #expect(runner.commands.first == "/usr/bin/xcrun simctl boot UDID-1")
}

@Test func eraseShutsDownRunningDeviceFirst() async throws {
    let (service, runner, terminations) = makeService()
    try await service.erase(runningDevice())
    #expect(runner.commands == [
        "/usr/bin/xcrun simctl shutdown UDID-1",
        "/usr/bin/xcrun simctl erase UDID-1",
        bootedList
    ])
    #expect(terminations.calls == [SimulatorHost.bundleIdentifiers])
}

@Test func eraseShutsDownBootingDeviceFirst() async throws {
    let (service, runner, _) = makeService()
    try await service.erase(bootingDevice())
    #expect(runner.commands.first == "/usr/bin/xcrun simctl shutdown UDID-1")
}

@Test func eraseStoppedDeviceErasesDirectly() async throws {
    let (service, runner, _) = makeService()
    try await service.erase(stoppedDevice())
    #expect(runner.commands.first == "/usr/bin/xcrun simctl erase UDID-1")
}
