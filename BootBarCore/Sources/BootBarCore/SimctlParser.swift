import Foundation

private struct SimctlDeviceList: Decodable {
    let devices: [String: [SimctlDevice]]
}

private struct SimctlDevice: Decodable {
    let udid: String
    let name: String
    let state: String
    let isAvailable: Bool
}

public enum SimctlParser {
    public static func parseDevices(json: String) throws -> [Device] {
        let list = try JSONDecoder().decode(SimctlDeviceList.self, from: Data(json.utf8))
        return list.devices
            .filter { $0.key.hasPrefix("com.apple.CoreSimulator.SimRuntime.iOS") }
            .flatMap { runtime, devices in
                devices.filter(\.isAvailable).map { device(from: $0, runtime: runtime) }
            }
            .sorted { $0.name < $1.name }
    }

    private static func device(from raw: SimctlDevice, runtime: String) -> Device {
        Device(id: raw.udid, name: raw.name, platform: .ios,
               osVersion: osVersion(fromRuntime: runtime), state: state(from: raw.state))
    }

    private static func osVersion(fromRuntime runtime: String) -> String {
        let raw = runtime.replacingOccurrences(of: "com.apple.CoreSimulator.SimRuntime.", with: "")
        let parts = raw.split(separator: "-")
        guard let name = parts.first else { return raw }
        return "\(name) " + parts.dropFirst().joined(separator: ".")
    }

    private static func state(from raw: String) -> DeviceState {
        switch raw {
        case "Booted": .running
        case "Booting": .booting
        default: .stopped
        }
    }
}
