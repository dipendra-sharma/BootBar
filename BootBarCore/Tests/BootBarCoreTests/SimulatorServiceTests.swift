import Testing
@testable import BootBarCore

private let bootedList = "/usr/bin/xcrun simctl list devices booted --json"
private let openSimulatorApp = "/usr/bin/open -a /Xcode/Applications/Simulator.app"

private func makeService(nothingBooted: Bool = true) -> (SimulatorService, MockShellRunner) {
    let runner = MockShellRunner()
    runner.responses["/usr/bin/xcode-select -p"] = .success("/Xcode\n")
    if nothingBooted {
        runner.responses[bootedList] = .success(#"{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-5":[]}}"#)
    }
    return (SimulatorService(runner: runner), runner)
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
    let (service, runner) = makeService()
    runner.responses["/usr/bin/xcrun simctl list devices --json"] = .success(#"{"devices":{}}"#)
    let devices = try await service.listDevices()
    #expect(devices.isEmpty)
    #expect(runner.commands == ["/usr/bin/xcrun simctl list devices --json"])
}

@Test func bootOpensSimulatorAppFromTheActiveDeveloperDirectory() async throws {
    let (service, runner) = makeService()
    try await service.boot("UDID-1")
    #expect(runner.commands == [
        "/usr/bin/xcrun simctl boot UDID-1",
        "/usr/bin/xcode-select -p",
        openSimulatorApp
    ])
}

@Test func bootSucceedsWhenSimulatorAppCannotBeOpened() async throws {
    let (service, runner) = makeService()
    runner.responses["/usr/bin/xcode-select -p"] =
        .failure(ShellError(command: "xcode-select", exitCode: 1, stderr: "no developer dir"))
    try await service.boot("UDID-1")
    #expect(runner.commands.contains("/usr/bin/xcrun simctl boot UDID-1"))
}

@Test func bootTreatsAlreadyBootedDeviceAsSuccess() async throws {
    let (service, runner) = makeService()
    runner.responses["/usr/bin/xcrun simctl boot UDID-1"] =
        .failure(ShellError(command: "boot", exitCode: 149, stderr: "current state: Booted"))
    runner.responses["/usr/bin/xcrun simctl list devices --json"] = .success(
        #"{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-5":[{"udid":"UDID-1","name":"iPhone","state":"Booted","isAvailable":true}]}}"#)
    try await service.boot("UDID-1")
    #expect(runner.commands.contains(openSimulatorApp))
}

@Test func bootRethrowsWhenDeviceDidNotActuallyBoot() async {
    let (service, runner) = makeService()
    runner.responses["/usr/bin/xcrun simctl boot UDID-1"] =
        .failure(ShellError(command: "boot", exitCode: 149, stderr: "device not found"))
    runner.responses["/usr/bin/xcrun simctl list devices --json"] = .success(#"{"devices":{}}"#)
    await #expect(throws: ShellError.self) {
        try await service.boot("UDID-1")
    }
}

@Test func shutdownQuitsSimulatorAppWhenNothingRemainsBooted() async throws {
    let (service, runner) = makeService()
    try await service.shutdown("UDID-1")
    #expect(runner.commands == [
        "/usr/bin/xcrun simctl shutdown UDID-1",
        bootedList,
        "/usr/bin/pkill -x Simulator"
    ])
}

@Test func shutdownKeepsSimulatorAppWhenAnotherDeviceBooted() async throws {
    let (service, runner) = makeService(nothingBooted: false)
    runner.responses[bootedList] = .success(
        #"{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-5":[{"udid":"B","name":"iPad","state":"Booted","isAvailable":true}]}}"#)
    try await service.shutdown("UDID-1")
    #expect(runner.commands == ["/usr/bin/xcrun simctl shutdown UDID-1", bootedList])
}

@Test func shutdownKeepsSimulatorAppWhenOnlyANonIOSDeviceBooted() async throws {
    let (service, runner) = makeService(nothingBooted: false)
    runner.responses[bootedList] = .success(
        #"{"devices":{"com.apple.CoreSimulator.SimRuntime.watchOS-11-5":[{"udid":"W","name":"Watch","state":"Booted","isAvailable":true}]}}"#)
    try await service.shutdown("UDID-1")
    #expect(!runner.commands.contains("/usr/bin/pkill -x Simulator"))
}

@Test func coldBootShutsDownRunningDeviceFirst() async throws {
    let (service, runner) = makeService()
    try await service.coldBoot(runningDevice())
    #expect(runner.commands == [
        "/usr/bin/xcrun simctl shutdown UDID-1",
        "/usr/bin/xcrun simctl boot UDID-1",
        "/usr/bin/xcode-select -p",
        openSimulatorApp
    ])
}

@Test func coldBootShutsDownBootingDeviceFirst() async throws {
    let (service, runner) = makeService()
    try await service.coldBoot(bootingDevice())
    #expect(runner.commands.first == "/usr/bin/xcrun simctl shutdown UDID-1")
}

@Test func coldBootSkipsShutdownWhenStopped() async throws {
    let (service, runner) = makeService()
    try await service.coldBoot(stoppedDevice())
    #expect(runner.commands.first == "/usr/bin/xcrun simctl boot UDID-1")
}

@Test func eraseShutsDownRunningDeviceFirst() async throws {
    let (service, runner) = makeService()
    try await service.erase(runningDevice())
    #expect(runner.commands == [
        "/usr/bin/xcrun simctl shutdown UDID-1",
        "/usr/bin/xcrun simctl erase UDID-1",
        bootedList,
        "/usr/bin/pkill -x Simulator"
    ])
}

@Test func eraseShutsDownBootingDeviceFirst() async throws {
    let (service, runner) = makeService()
    try await service.erase(bootingDevice())
    #expect(runner.commands.first == "/usr/bin/xcrun simctl shutdown UDID-1")
}

@Test func eraseStoppedDeviceErasesDirectly() async throws {
    let (service, runner) = makeService()
    try await service.erase(stoppedDevice())
    #expect(runner.commands.first == "/usr/bin/xcrun simctl erase UDID-1")
}
