import Testing
@testable import BootBarCore

@MainActor
private func makeViewModel(sdkRoot: String? = "/sdk") -> (DeviceListViewModel, MockShellRunner) {
    let runner = MockShellRunner()
    let vm = DeviceListViewModel(runner: runner) {
        sdkRoot.map(AndroidSDK.init(root:))
    }
    return (vm, runner)
}

private func emptySimctl(_ runner: MockShellRunner) {
    runner.responses["/usr/bin/xcrun simctl list devices --json"] = .success(#"{"devices":{}}"#)
}

private func emptyAndroid(_ runner: MockShellRunner) {
    runner.responses["/sdk/emulator/emulator -list-avds"] = .success("")
    runner.responses["/sdk/platform-tools/adb devices"] = .success("List of devices attached\n")
}

@MainActor
@Test func refreshPopulatesBothPlatforms() async {
    let (vm, runner) = makeViewModel()
    runner.responses["/usr/bin/xcrun simctl list devices --json"] = .success(
        #"{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-5":[{"udid":"A","name":"iPhone 16","state":"Shutdown","isAvailable":true}]}}"#)
    runner.responses["/sdk/emulator/emulator -list-avds"] = .success("Pixel_8\n")
    runner.responses["/sdk/platform-tools/adb devices"] = .success("List of devices attached\n")
    await vm.refresh()
    #expect(vm.iosDevices.count == 1)
    #expect(vm.androidDevices.count == 1)
    #expect(vm.iosError == nil)
    #expect(vm.androidError == nil)
}

@MainActor
@Test func missingSdkSetsAndroidErrorOnly() async {
    let (vm, runner) = makeViewModel(sdkRoot: nil)
    emptySimctl(runner)
    await vm.refresh()
    #expect(vm.iosError == nil)
    #expect(vm.androidError == "Android SDK not found — set path in Settings")
    #expect(vm.androidDevices.isEmpty)
}

@MainActor
@Test func iosFailureDoesNotBlockAndroid() async {
    let (vm, runner) = makeViewModel()
    runner.responses["/usr/bin/xcrun simctl list devices --json"] =
        .failure(ShellError(command: "simctl", exitCode: 1, stderr: "xcrun broken"))
    emptyAndroid(runner)
    await vm.refresh()
    #expect(vm.iosError == "xcrun broken")
    #expect(vm.androidError == nil)
}

@MainActor
@Test func failedActionRecordsRowErrorAndClearsBusy() async {
    let (vm, runner) = makeViewModel()
    emptySimctl(runner)
    emptyAndroid(runner)
    runner.responses["/usr/bin/xcrun simctl boot UDID-1"] =
        .failure(ShellError(command: "boot", exitCode: 149, stderr: "Unable to boot"))
    let device = Device(id: "UDID-1", name: "iPhone", platform: .ios, osVersion: "iOS 18.5", state: .stopped)
    await vm.perform(.start, on: device)
    #expect(vm.rowErrors["UDID-1"] == "Unable to boot")
    #expect(vm.busyDeviceIds.isEmpty)
}

@MainActor
@Test func successfulActionRefreshesAndClearsRowError() async {
    let (vm, runner) = makeViewModel()
    emptySimctl(runner)
    emptyAndroid(runner)
    let device = Device(id: "UDID-1", name: "iPhone", platform: .ios, osVersion: "iOS 18.5", state: .stopped)
    await vm.perform(.start, on: device)
    #expect(vm.rowErrors["UDID-1"] == nil)
    #expect(runner.commands.contains("/usr/bin/xcrun simctl boot UDID-1"))
    #expect(runner.commands.contains("/usr/bin/xcrun simctl list devices --json"))
}

@MainActor
@Test func androidActionsRouteToEmulatorService() async {
    let (vm, runner) = makeViewModel()
    emptySimctl(runner)
    emptyAndroid(runner)
    let device = Device(id: "Pixel_8", name: "Pixel_8", platform: .android,
                        osVersion: "API 34", state: .stopped)
    await vm.perform(.start, on: device)
    #expect(runner.commands.contains("detached /sdk/emulator/emulator -avd Pixel_8"))
}

@MainActor
@Test func startMarksDeviceBootingUntilRunning() async {
    let (vm, runner) = makeViewModel()
    emptySimctl(runner)
    runner.responses["/sdk/emulator/emulator -list-avds"] = .success("Pixel_8\n")
    runner.responses["/sdk/platform-tools/adb devices"] = .success("List of devices attached\n")
    let device = Device(id: "Pixel_8", name: "Pixel_8", platform: .android,
                        osVersion: "API 34", state: .stopped)
    await vm.perform(.start, on: device)
    #expect(vm.androidDevices.first?.state == .booting)
    runner.responses["/sdk/platform-tools/adb devices"] = .success("List of devices attached\nemulator-5554\tdevice\n")
    runner.responses["/sdk/platform-tools/adb -s emulator-5554 emu avd name"] = .success("Pixel_8\nOK\n")
    await vm.refresh()
    #expect(vm.androidDevices.first?.state == .running)
}

@MainActor
@Test func staleAndroidRefreshDoesNotOverwriteNewerState() async {
    let (vm, runner) = makeViewModel()
    emptySimctl(runner)
    runner.responses["/sdk/emulator/emulator -list-avds"] = .success("Pixel_8\nPixel_9\n")
    runner.responses["/sdk/platform-tools/adb devices"] =
        .success("List of devices attached\nemulator-5554\tdevice\nemulator-5556\tdevice\n")
    runner.responses["/sdk/platform-tools/adb -s emulator-5554 emu avd name"] = .success("Pixel_8\nOK\n")
    runner.responses["/sdk/platform-tools/adb -s emulator-5556 emu avd name"] = .success("Pixel_9\nOK\n")
    await vm.refresh()
    #expect(vm.androidDevices.map(\.state) == [.running, .running])

    runner.delays["/sdk/platform-tools/adb -s emulator-5556 emu avd name"] = .milliseconds(500)
    let staleRefresh = Task { await vm.refresh() }
    try? await Task.sleep(for: .milliseconds(100))

    runner.delays = [:]
    runner.responses["/sdk/platform-tools/adb devices"] =
        .success("List of devices attached\nemulator-5554\tdevice\n")
    let pixel9 = vm.androidDevices.first { $0.id == "Pixel_9" }
    #expect(pixel9 != nil)
    if let pixel9 {
        await vm.perform(.stop, on: pixel9)
    }
    #expect(vm.androidDevices.first { $0.id == "Pixel_9" }?.state == .stopped)

    await staleRefresh.value
    #expect(vm.androidDevices.first { $0.id == "Pixel_9" }?.state == .stopped)
}

@MainActor
@Test func staleIOSRefreshDoesNotOverwriteNewerState() async {
    let (vm, runner) = makeViewModel()
    emptyAndroid(runner)
    let simctlList = "/usr/bin/xcrun simctl list devices --json"
    let booted = #"{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-5":[{"udid":"A","name":"iPhone 16","state":"Booted","isAvailable":true}]}}"#
    let shutdown = #"{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-5":[{"udid":"A","name":"iPhone 16","state":"Shutdown","isAvailable":true}]}}"#
    runner.responses[simctlList] = .success(booted)
    await vm.refresh()
    #expect(vm.iosDevices.first?.state == .running)

    runner.delays[simctlList] = .milliseconds(500)
    let staleRefresh = Task { await vm.refresh() }
    try? await Task.sleep(for: .milliseconds(100))

    runner.delays = [:]
    runner.responses[simctlList] = .success(shutdown)
    let device = vm.iosDevices[0]
    await vm.perform(.stop, on: device)
    #expect(vm.iosDevices.first?.state == .stopped)

    await staleRefresh.value
    #expect(vm.iosDevices.first?.state == .stopped)
}

@MainActor
@Test func iosEraseDoesNotMarkBooting() async {
    let (vm, runner) = makeViewModel()
    emptySimctl(runner)
    emptyAndroid(runner)
    runner.responses["/usr/bin/xcrun simctl list devices --json"] = .success(
        #"{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-5":[{"udid":"A","name":"iPhone 16","state":"Shutdown","isAvailable":true}]}}"#)
    let device = Device(id: "A", name: "iPhone 16", platform: .ios, osVersion: "iOS 18.5", state: .stopped)
    await vm.perform(.erase, on: device)
    #expect(vm.iosDevices.first?.state == .stopped)
}
