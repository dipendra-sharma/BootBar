import Testing
@testable import BootBarCore

private func makeService() -> (SimulatorService, MockShellRunner) {
    let runner = MockShellRunner()
    return (SimulatorService(runner: runner), runner)
}

private func runningDevice() -> Device {
    Device(id: "UDID-1", name: "iPhone 16 Pro", platform: .ios, osVersion: "iOS 18.5", state: .running)
}

private func stoppedDevice() -> Device {
    Device(id: "UDID-1", name: "iPhone 16 Pro", platform: .ios, osVersion: "iOS 18.5", state: .stopped)
}

@Test func listDevicesIssuesSimctlList() async throws {
    let (service, runner) = makeService()
    runner.responses["/usr/bin/xcrun simctl list devices --json"] = .success(#"{"devices":{}}"#)
    let devices = try await service.listDevices()
    #expect(devices.isEmpty)
    #expect(runner.commands == ["/usr/bin/xcrun simctl list devices --json"])
}

@Test func bootIssuesBootAndOpensSimulatorApp() async throws {
    let (service, runner) = makeService()
    try await service.boot("UDID-1")
    #expect(runner.commands == [
        "/usr/bin/xcrun simctl boot UDID-1",
        "/usr/bin/open -a Simulator"
    ])
}

@Test func shutdownQuitsSimulatorAppWhenNothingRemainsBooted() async throws {
    let (service, runner) = makeService()
    runner.responses["/usr/bin/xcrun simctl list devices --json"] = .success(#"{"devices":{}}"#)
    try await service.shutdown("UDID-1")
    #expect(runner.commands == [
        "/usr/bin/xcrun simctl shutdown UDID-1",
        "/usr/bin/xcrun simctl list devices --json",
        "/usr/bin/pkill -x Simulator"
    ])
}

@Test func shutdownKeepsSimulatorAppWhenAnotherDeviceBooted() async throws {
    let (service, runner) = makeService()
    runner.responses["/usr/bin/xcrun simctl list devices --json"] = .success(
        #"{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-5":[{"udid":"B","name":"iPad","state":"Booted","isAvailable":true}]}}"#)
    try await service.shutdown("UDID-1")
    #expect(runner.commands == [
        "/usr/bin/xcrun simctl shutdown UDID-1",
        "/usr/bin/xcrun simctl list devices --json"
    ])
}

@Test func coldBootShutsDownRunningDeviceFirst() async throws {
    let (service, runner) = makeService()
    try await service.coldBoot(runningDevice())
    #expect(runner.commands == [
        "/usr/bin/xcrun simctl shutdown UDID-1",
        "/usr/bin/xcrun simctl boot UDID-1",
        "/usr/bin/open -a Simulator"
    ])
}

@Test func coldBootSkipsShutdownWhenStopped() async throws {
    let (service, runner) = makeService()
    try await service.coldBoot(stoppedDevice())
    #expect(runner.commands.first == "/usr/bin/xcrun simctl boot UDID-1")
}

@Test func eraseShutsDownRunningDeviceFirst() async throws {
    let (service, runner) = makeService()
    runner.responses["/usr/bin/xcrun simctl list devices --json"] = .success(#"{"devices":{}}"#)
    try await service.erase(runningDevice())
    #expect(runner.commands == [
        "/usr/bin/xcrun simctl shutdown UDID-1",
        "/usr/bin/xcrun simctl erase UDID-1",
        "/usr/bin/xcrun simctl list devices --json",
        "/usr/bin/pkill -x Simulator"
    ])
}

@Test func eraseStoppedDeviceErasesDirectly() async throws {
    let (service, runner) = makeService()
    runner.responses["/usr/bin/xcrun simctl list devices --json"] = .success(#"{"devices":{}}"#)
    try await service.erase(stoppedDevice())
    #expect(runner.commands.first == "/usr/bin/xcrun simctl erase UDID-1")
}
