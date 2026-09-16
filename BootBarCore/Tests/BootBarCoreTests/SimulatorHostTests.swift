import Testing
@testable import BootBarCore

private let developerDirectory = "/Xcode.app/Contents/Developer"
private let legacySimulatorApp = "/Xcode.app/Contents/Developer/Applications/Simulator.app"
private let deviceHubApp = "/Xcode.app/Contents/Applications/DeviceHub.app"

private func locator(installed: Set<String>) -> SimulatorHostLocator {
    SimulatorHostLocator { installed.contains($0) }
}

@Test func locatesSimulatorAppOnXcode26AndEarlier() {
    let host = locator(installed: [legacySimulatorApp]).locate(developerDirectory: developerDirectory)
    #expect(host?.bundlePath == legacySimulatorApp)
}

@Test func locatesDeviceHubOnXcode27() {
    let host = locator(installed: [deviceHubApp]).locate(developerDirectory: developerDirectory)
    #expect(host?.bundlePath == deviceHubApp)
}

@Test func prefersSimulatorAppWhenBothAreInstalled() {
    let host = locator(installed: [legacySimulatorApp, deviceHubApp])
        .locate(developerDirectory: developerDirectory)
    #expect(host?.bundlePath == legacySimulatorApp)
}

@Test func locatesNothingWhenNeitherAppIsInstalled() {
    #expect(locator(installed: []).locate(developerDirectory: developerDirectory) == nil)
}

@Test func toleratesTrailingSlashOnDeveloperDirectory() {
    let host = locator(installed: [deviceHubApp]).locate(developerDirectory: developerDirectory + "/")
    #expect(host?.bundlePath == deviceHubApp)
}

@Test func knownBundleIdentifiersCoverBothHostApps() {
    #expect(SimulatorHost.bundleIdentifiers.contains("com.apple.iphonesimulator"))
    #expect(SimulatorHost.bundleIdentifiers.contains("com.apple.dt.Devices"))
}
