import Foundation
import Testing
@testable import BootBarCore

private func makeService(configIni: String? = "image.sysdir.1=system-images/android-35/google_apis/arm64-v8a/") -> (EmulatorService, MockShellRunner) {
    let runner = MockShellRunner()
    let sdk = AndroidSDK(root: "/sdk")
    let service = EmulatorService(runner: runner, sdk: sdk, avdHome: "/avd") { _ in configIni }
    return (service, runner)
}

private func setupListResponses(_ runner: MockShellRunner) {
    runner.responses["/sdk/emulator/emulator -list-avds"] = .success("Pixel_9_Pro\nPixel_8\n")
    runner.responses["/sdk/platform-tools/adb devices"] = .success("List of devices attached\nemulator-5554\tdevice\n")
    runner.responses["/sdk/platform-tools/adb -s emulator-5554 emu avd name"] = .success("Pixel_9_Pro\r\nOK\r\n")
}

@Test func listMapsRunningStateAndSerial() async throws {
    let (service, runner) = makeService()
    setupListResponses(runner)
    let devices = try await service.listDevices()
    #expect(devices.count == 2)
    let pixel9 = devices.first { $0.name == "Pixel_9_Pro" }
    #expect(pixel9?.state == .running)
    #expect(pixel9?.serial == "emulator-5554")
    let pixel8 = devices.first { $0.name == "Pixel_8" }
    #expect(pixel8?.state == .stopped)
    #expect(pixel8?.serial == nil)
}

@Test func listReadsApiLevelFromConfig() async throws {
    let (service, runner) = makeService()
    setupListResponses(runner)
    let devices = try await service.listDevices()
    #expect(devices.first?.osVersion == "API 35")
}

@Test func listFallsBackWhenConfigMissing() async throws {
    let (service, runner) = makeService(configIni: nil)
    setupListResponses(runner)
    let devices = try await service.listDevices()
    #expect(devices.first?.osVersion == "Android")
}

@Test func startLaunchesDetachedEmulator() throws {
    let (service, runner) = makeService()
    try service.start("Pixel_8")
    #expect(runner.commands == ["detached /sdk/emulator/emulator -avd Pixel_8"])
}

@Test func stopKillsViaAdb() async throws {
    let (service, runner) = makeService()
    try await service.stop(serial: "emulator-5554")
    #expect(runner.commands == ["/sdk/platform-tools/adb -s emulator-5554 emu kill"])
}

@Test func coldBootRunningDeviceKillsThenStartsWithNoSnapshot() async throws {
    let (service, runner) = makeService()
    let device = Device(id: "Pixel_9_Pro", name: "Pixel_9_Pro", platform: .android,
                        osVersion: "API 35", state: .running, serial: "emulator-5554")
    try await service.coldBoot(device)
    #expect(runner.commands == [
        "/sdk/platform-tools/adb -s emulator-5554 emu kill",
        "detached /sdk/emulator/emulator -avd Pixel_9_Pro -no-snapshot-load"
    ])
}

@Test func wipeStoppedDeviceStartsWithWipeData() async throws {
    let (service, runner) = makeService()
    let device = Device(id: "Pixel_8", name: "Pixel_8", platform: .android,
                        osVersion: "API 34", state: .stopped)
    try await service.wipe(device)
    #expect(runner.commands == ["detached /sdk/emulator/emulator -avd Pixel_8 -wipe-data"])
}
