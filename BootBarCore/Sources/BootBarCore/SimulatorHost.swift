import AppKit
import Foundation

public struct SimulatorHost: Sendable, Equatable {
    public static let bundleIdentifiers: Set<String> = ["com.apple.iphonesimulator", "com.apple.dt.Devices"]

    public let bundlePath: String

    public init(bundlePath: String) {
        self.bundlePath = bundlePath
    }

    public static func terminateRunning(_ bundleIdentifiers: Set<String>) {
        for identifier in bundleIdentifiers {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: identifier) {
                app.terminate()
            }
        }
    }
}

public struct SimulatorHostLocator: Sendable {
    private let exists: @Sendable (String) -> Bool

    public init(exists: @escaping @Sendable (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }) {
        self.exists = exists
    }

    public func locate(developerDirectory: String) -> SimulatorHost? {
        candidates(developerDirectory: developerDirectory)
            .first { exists($0) }
            .map(SimulatorHost.init(bundlePath:))
    }

    private func candidates(developerDirectory: String) -> [String] {
        let developer = developerDirectory as NSString
        let xcodeContents = developer.deletingLastPathComponent as NSString
        return [
            developer.appendingPathComponent("Applications/Simulator.app"),
            xcodeContents.appendingPathComponent("Applications/DeviceHub.app")
        ]
    }
}
