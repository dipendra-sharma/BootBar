import Foundation
import os
import Testing
@testable import BootBarCore

private final class ChangeSignal: @unchecked Sendable {
    private let mutex = OSAllocatedUnfairLock(initialState: 0)

    func fire() {
        mutex.withLock { $0 += 1 }
    }

    func waitForFire(timeout: Duration = .seconds(3)) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if mutex.withLock({ $0 > 0 }) { return true }
            try? await Task.sleep(for: .milliseconds(25))
        }
        return false
    }
}

private func makeTemporaryRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

@Test func reportsStateFileAppearingInsideADeviceDirectory() async throws {
    let root = try makeTemporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let device = root.appendingPathComponent("DEVICE-1")
    try FileManager.default.createDirectory(at: device, withIntermediateDirectories: true)

    let signal = ChangeSignal()
    let watcher = DeviceDirectoryWatcher(rootPath: root.path, debounceInterval: .milliseconds(50))
    watcher.start { signal.fire() }
    defer { watcher.stop() }
    try await Task.sleep(for: .milliseconds(200))

    try Data().write(to: device.appendingPathComponent("hardware-qemu.ini.lock"))

    #expect(await signal.waitForFire())
}

@Test func reportsStateFileDisappearing() async throws {
    let root = try makeTemporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let device = root.appendingPathComponent("DEVICE-1")
    try FileManager.default.createDirectory(at: device, withIntermediateDirectories: true)
    let lock = device.appendingPathComponent("hardware-qemu.ini.lock")
    try Data().write(to: lock)

    let signal = ChangeSignal()
    let watcher = DeviceDirectoryWatcher(rootPath: root.path, debounceInterval: .milliseconds(50))
    watcher.start { signal.fire() }
    defer { watcher.stop() }
    try await Task.sleep(for: .milliseconds(200))

    try FileManager.default.removeItem(at: lock)

    #expect(await signal.waitForFire())
}

@Test func picksUpDevicesCreatedAfterWatchingStarted() async throws {
    let root = try makeTemporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }

    let signal = ChangeSignal()
    let watcher = DeviceDirectoryWatcher(rootPath: root.path, debounceInterval: .milliseconds(50))
    watcher.start { signal.fire() }
    defer { watcher.stop() }
    try await Task.sleep(for: .milliseconds(200))

    let device = root.appendingPathComponent("DEVICE-2")
    try FileManager.default.createDirectory(at: device, withIntermediateDirectories: true)
    #expect(await signal.waitForFire())

    let later = ChangeSignal()
    watcher.start { later.fire() }
    try await Task.sleep(for: .milliseconds(200))
    try Data().write(to: device.appendingPathComponent("device.plist"))

    #expect(await later.waitForFire())
}

@Test func stopEndsNotifications() async throws {
    let root = try makeTemporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let device = root.appendingPathComponent("DEVICE-1")
    try FileManager.default.createDirectory(at: device, withIntermediateDirectories: true)

    let signal = ChangeSignal()
    let watcher = DeviceDirectoryWatcher(rootPath: root.path, debounceInterval: .milliseconds(50))
    watcher.start { signal.fire() }
    try await Task.sleep(for: .milliseconds(200))
    watcher.stop()
    try await Task.sleep(for: .milliseconds(100))

    try Data().write(to: device.appendingPathComponent("device.plist"))

    #expect(await signal.waitForFire(timeout: .milliseconds(500)) == false)
}
