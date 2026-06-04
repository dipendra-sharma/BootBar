import Testing
@testable import BootBarCore

private func locator(override: String?, env: [String: String], valid: Set<String>) -> SDKLocator {
    SDKLocator(override: override, environment: env, home: "/Users/test") { path in
        valid.contains(path)
    }
}

private func binaries(_ root: String) -> Set<String> {
    ["\(root)/emulator/emulator", "\(root)/platform-tools/adb"]
}

@Test func overrideWinsOverEnvironment() {
    let sdk = locator(override: "/custom/sdk",
                      env: ["ANDROID_HOME": "/env/sdk"],
                      valid: binaries("/custom/sdk").union(binaries("/env/sdk"))).locate()
    #expect(sdk?.emulatorPath == "/custom/sdk/emulator/emulator")
}

@Test func androidHomeWinsOverSdkRoot() {
    let sdk = locator(override: nil,
                      env: ["ANDROID_HOME": "/home/sdk", "ANDROID_SDK_ROOT": "/root/sdk"],
                      valid: binaries("/home/sdk").union(binaries("/root/sdk"))).locate()
    #expect(sdk?.adbPath == "/home/sdk/platform-tools/adb")
}

@Test func fallsBackToDefaultLocation() {
    let sdk = locator(override: nil, env: [:],
                      valid: binaries("/Users/test/Library/Android/sdk")).locate()
    #expect(sdk?.emulatorPath == "/Users/test/Library/Android/sdk/emulator/emulator")
}

@Test func skipsCandidateMissingBinaries() {
    let sdk = locator(override: "/broken/sdk", env: [:],
                      valid: binaries("/Users/test/Library/Android/sdk")).locate()
    #expect(sdk?.adbPath == "/Users/test/Library/Android/sdk/platform-tools/adb")
}

@Test func returnsNilWhenNothingFound() {
    #expect(locator(override: nil, env: [:], valid: []).locate() == nil)
}

@Test func ignoresEmptyOverride() {
    let sdk = locator(override: "", env: [:],
                      valid: binaries("/Users/test/Library/Android/sdk")).locate()
    #expect(sdk != nil)
}
