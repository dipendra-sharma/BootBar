import Foundation
import ServiceManagement

public protocol LoginItemControlling {
    var isRegistered: Bool { get }
    func register() throws
    func unregister() throws
}

public struct SMAppServiceLoginItem: LoginItemControlling {
    private let service = SMAppService.mainApp

    public init() {}

    public var isRegistered: Bool { service.status == .enabled }

    public func register() throws { try service.register() }

    public func unregister() throws { try service.unregister() }
}

public struct LaunchAtLogin {
    private let control: LoginItemControlling

    public init(control: LoginItemControlling = SMAppServiceLoginItem()) {
        self.control = control
    }

    public var isEnabled: Bool { control.isRegistered }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard !control.isRegistered else { return }
            try control.register()
        } else {
            guard control.isRegistered else { return }
            try control.unregister()
        }
    }
}
