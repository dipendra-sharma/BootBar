import Foundation
import Observation

@MainActor
@Observable
public final class DeviceListViewModel {
    public private(set) var iosDevices: [Device] = []
    public private(set) var androidDevices: [Device] = []
    public private(set) var iosError: String?
    public private(set) var androidError: String?
    public private(set) var busyDeviceIds: Set<String> = []
    public private(set) var rowErrors: [String: String] = [:]

    private let simulatorService: SimulatorService
    private let runner: any ShellRunner
    private let locateSDK: @Sendable () -> AndroidSDK?
    private var awaitingBoot: Set<String> = []
    private var refreshGeneration = 0

    public init(runner: any ShellRunner = ProcessShellRunner(),
                locateSDK: @escaping @Sendable () -> AndroidSDK?) {
        self.runner = runner
        self.simulatorService = SimulatorService(runner: runner)
        self.locateSDK = locateSDK
    }

    public func refresh() async {
        refreshGeneration += 1
        let generation = refreshGeneration
        async let ios = loadIOS()
        async let android = loadAndroid()
        let iosResult = await ios
        let androidResult = await android
        guard generation == refreshGeneration else { return }
        (iosDevices, iosError) = (overlayBooting(iosResult.0), iosResult.1)
        (androidDevices, androidError) = (overlayBooting(androidResult.0), androidResult.1)
    }

    public func perform(_ action: DeviceAction, on device: Device) async {
        busyDeviceIds.insert(device.id)
        rowErrors[device.id] = nil
        do {
            try await execute(action, on: device)
            if expectsBoot(action, device) {
                awaitingBoot.insert(device.id)
            } else {
                awaitingBoot.remove(device.id)
            }
        } catch {
            rowErrors[device.id] = friendlyMessage(error)
        }
        busyDeviceIds.remove(device.id)
        await refresh()
    }

    private func loadIOS() async -> ([Device], String?) {
        do {
            return (try await simulatorService.listDevices(), nil)
        } catch {
            return (iosDevices, friendlyMessage(error))
        }
    }

    private func loadAndroid() async -> ([Device], String?) {
        guard let service = emulatorService() else {
            return ([], "Android SDK not found — set path in Settings")
        }
        do {
            return (try await service.listDevices(), nil)
        } catch {
            return (androidDevices, friendlyMessage(error))
        }
    }

    private func execute(_ action: DeviceAction, on device: Device) async throws {
        switch device.platform {
        case .ios: try await executeIOS(action, on: device)
        case .android: try await executeAndroid(action, on: device)
        }
    }

    private func executeIOS(_ action: DeviceAction, on device: Device) async throws {
        switch action {
        case .start: try await simulatorService.boot(device.id)
        case .stop: try await simulatorService.shutdown(device.id)
        case .coldBoot: try await simulatorService.coldBoot(device)
        case .erase: try await simulatorService.erase(device)
        }
    }

    private func executeAndroid(_ action: DeviceAction, on device: Device) async throws {
        guard let service = emulatorService() else {
            throw ShellError(command: "android", exitCode: 1, stderr: "Android SDK not found")
        }
        switch action {
        case .start: try service.start(device.name)
        case .stop: try await service.stop(serial: device.serial ?? "")
        case .coldBoot: try await service.coldBoot(device)
        case .erase: try await service.wipe(device)
        }
    }

    private func expectsBoot(_ action: DeviceAction, _ device: Device) -> Bool {
        switch action {
        case .start, .coldBoot: true
        case .erase: device.platform == .android
        case .stop: false
        }
    }

    private func overlayBooting(_ devices: [Device]) -> [Device] {
        devices.map { device in
            guard awaitingBoot.contains(device.id) else { return device }
            guard device.state != .running else {
                awaitingBoot.remove(device.id)
                return device
            }
            return device.withState(.booting)
        }
    }

    private func emulatorService() -> EmulatorService? {
        locateSDK().map { EmulatorService(runner: runner, sdk: $0) }
    }

    private func friendlyMessage(_ error: Error) -> String {
        guard let shellError = error as? ShellError else { return error.localizedDescription }
        return shellError.stderr.isEmpty ? "Command failed (exit \(shellError.exitCode))" : shellError.stderr
    }
}
