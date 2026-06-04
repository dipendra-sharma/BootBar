public enum Platform: String, Sendable, CaseIterable {
    case ios
    case android
}

public enum DeviceState: Sendable, Equatable {
    case stopped
    case booting
    case running
}

public enum DeviceAction: Sendable {
    case start
    case stop
    case coldBoot
    case erase
}

public struct Device: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let platform: Platform
    public let osVersion: String
    public let state: DeviceState
    public let serial: String?

    public init(id: String, name: String, platform: Platform, osVersion: String, state: DeviceState, serial: String? = nil) {
        self.id = id
        self.name = name
        self.platform = platform
        self.osVersion = osVersion
        self.state = state
        self.serial = serial
    }

    public func withState(_ newState: DeviceState) -> Device {
        Device(id: id, name: name, platform: platform, osVersion: osVersion, state: newState, serial: serial)
    }
}
