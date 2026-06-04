import Foundation

public struct AndroidSDK: Sendable, Equatable {
    public let emulatorPath: String
    public let adbPath: String

    public init(root: String) {
        emulatorPath = root + "/emulator/emulator"
        adbPath = root + "/platform-tools/adb"
    }
}

public struct SDKLocator: Sendable {
    private let override: String?
    private let environment: [String: String]
    private let home: String
    private let isExecutable: @Sendable (String) -> Bool

    public init(override: String?,
                environment: [String: String] = ProcessInfo.processInfo.environment,
                home: String = NSHomeDirectory(),
                isExecutable: @escaping @Sendable (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }) {
        self.override = override
        self.environment = environment
        self.home = home
        self.isExecutable = isExecutable
    }

    public func locate() -> AndroidSDK? {
        candidates()
            .map(AndroidSDK.init(root:))
            .first { isExecutable($0.emulatorPath) && isExecutable($0.adbPath) }
    }

    private func candidates() -> [String] {
        [override, environment["ANDROID_HOME"], environment["ANDROID_SDK_ROOT"], home + "/Library/Android/sdk"]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
    }
}
