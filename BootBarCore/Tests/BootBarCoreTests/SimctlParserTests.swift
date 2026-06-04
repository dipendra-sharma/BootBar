import Testing
@testable import BootBarCore

private let fixture = """
{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-5":[{"udid":"AAA-111","name":"iPhone 16 Pro","state":"Booted","isAvailable":true},{"udid":"BBB-222","name":"iPhone 16","state":"Shutdown","isAvailable":true},{"udid":"CCC-333","name":"Broken","state":"Shutdown","isAvailable":false},{"udid":"DDD-444","name":"iPhone SE","state":"Booting","isAvailable":true}],"com.apple.CoreSimulator.SimRuntime.watchOS-11-0":[{"udid":"EEE-555","name":"Watch","state":"Shutdown","isAvailable":true}]}}
"""

@Test func parsesAvailableIOSDevices() throws {
    let devices = try SimctlParser.parseDevices(json: fixture)
    #expect(devices.count == 3)
    #expect(devices.allSatisfy { $0.platform == .ios })
}

@Test func excludesNonIOSRuntimes() throws {
    let devices = try SimctlParser.parseDevices(json: fixture)
    #expect(!devices.contains { $0.name == "Watch" })
}

@Test func mapsStates() throws {
    let devices = try SimctlParser.parseDevices(json: fixture)
    let byId = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, $0) })
    #expect(byId["AAA-111"]?.state == .running)
    #expect(byId["BBB-222"]?.state == .stopped)
    #expect(byId["DDD-444"]?.state == .booting)
}

@Test func formatsRuntimeAsOSVersion() throws {
    let devices = try SimctlParser.parseDevices(json: fixture)
    #expect(devices.first?.osVersion == "iOS 18.5")
}

@Test func throwsOnInvalidJSON() {
    #expect(throws: Error.self) {
        try SimctlParser.parseDevices(json: "not json")
    }
}
