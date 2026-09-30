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
    private let bootTimeout: Duration
    private let now: @Sendable () -> ContinuousClock.Instant
    private var bootDeadlines: [String: ContinuousClock.Instant] = [:]
    private var refreshChain: Task<Void, Never>?
    private let watchers = [
        DeviceDirectoryWatcher(rootPath: DeviceDirectoryWatcher.coreSimulatorDevices),
        DeviceDirectoryWatcher(rootPath: DeviceDirectoryWatcher.androidAVDs)
    ]
    private var isWatching = false
    private var settleTask: Task<Void, Never>?

    public init(runner: any ShellRunner = ProcessShellRunner(),
                bootTimeout: Duration = .seconds(60),
                now: @escaping @Sendable () -> ContinuousClock.Instant = { ContinuousClock.now },
                locateSDK: @escaping @Sendable () -> AndroidSDK?) {
        self.runner = runner
        self.simulatorService = SimulatorService(runner: runner)
        self.bootTimeout = bootTimeout
        self.now = now
        self.locateSDK = locateSDK
    }

    public var runningCount: Int {
        (iosDevices + androidDevices).count { $0.state == .running }
    }

    public func startWatchingDevices() {
        guard !isWatching else { return }
        isWatching = true
        Task { @MainActor in await refresh() }
        for watcher in watchers {
            watcher.start { [weak self] in
                Task { @MainActor in await self?.refresh() }
            }
        }
    }

    private func scheduleSettleRefreshIfBooting() {
        settleTask?.cancel()
        guard (androidDevices + iosDevices).contains(where: { $0.state == .booting }) else { return }
        settleTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await refresh()
        }
    }

    public func refresh() async {
        let previous = refreshChain
        let task = Task { @MainActor in
            await previous?.value
            await self.reload()
        }
        refreshChain = task
        await task.value
        if refreshChain == task { refreshChain = nil }
    }

    private func reload() async {
        async let ios = loadIOS()
        async let android = loadAndroid()
        let iosResult = await ios
        let androidResult = await android
        pruneBootDeadlines(presentIds: Set(iosResult.0.map(\.id)).union(androidResult.0.map(\.id)))
        (iosDevices, iosError) = (overlayBooting(iosResult.0), iosResult.1)
        (androidDevices, androidError) = (overlayBooting(androidResult.0), androidResult.1)
        scheduleSettleRefreshIfBooting()
    }

    public func perform(_ action: DeviceAction, on device: Device) async {
        busyDeviceIds.insert(device.id)
        rowErrors[device.id] = nil
        do {
            try await execute(action, on: device)
            if expectsBoot(action, device) {
                bootDeadlines[device.id] = now() + bootTimeout
            } else {
                bootDeadlines[device.id] = nil
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
        case .start: try await service.start(device.name)
        case .stop: try await service.stop(serial: try serial(of: device))
        case .coldBoot: try await service.coldBoot(device)
        case .erase: try await service.wipe(device)
        }
    }

    private func serial(of device: Device) throws -> String {
        guard let serial = device.serial else {
            throw ShellError(command: "adb emu kill", exitCode: 1,
                             stderr: "\(device.name) is not running")
        }
        return serial
    }

    private func expectsBoot(_ action: DeviceAction, _ device: Device) -> Bool {
        switch action {
        case .start, .coldBoot: true
        case .erase: device.platform == .android
        case .stop: false
        }
    }

    private func pruneBootDeadlines(presentIds: Set<String>) {
        let currentTime = now()
        bootDeadlines = bootDeadlines.filter { id, deadline in
            presentIds.contains(id) && currentTime < deadline
        }
    }

    private func overlayBooting(_ devices: [Device]) -> [Device] {
        devices.map { device in
            guard bootDeadlines[device.id] != nil else { return device }
            guard device.state == .stopped else {
                bootDeadlines[device.id] = nil
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
