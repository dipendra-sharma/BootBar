import Testing
import Foundation
@testable import BootBarCore

final class FakeLoginItem: LoginItemControlling, @unchecked Sendable {
    private let lock = NSLock()
    private var registered: Bool
    private(set) var registerCalls = 0
    private(set) var unregisterCalls = 0

    init(registered: Bool = false) { self.registered = registered }

    var isRegistered: Bool { lock.withLock { registered } }

    func register() throws {
        lock.withLock { registerCalls += 1; registered = true }
    }

    func unregister() throws {
        lock.withLock { unregisterCalls += 1; registered = false }
    }
}

struct ThrowingLoginItem: LoginItemControlling {
    struct Failure: Error {}
    var isRegistered: Bool { false }
    func register() throws { throw Failure() }
    func unregister() throws { throw Failure() }
}

@Test func isEnabledReflectsRegistration() {
    #expect(LaunchAtLogin(control: FakeLoginItem(registered: true)).isEnabled == true)
    #expect(LaunchAtLogin(control: FakeLoginItem(registered: false)).isEnabled == false)
}

@Test func enablingRegistersWhenNotRegistered() throws {
    let fake = FakeLoginItem(registered: false)
    try LaunchAtLogin(control: fake).setEnabled(true)
    #expect(fake.registerCalls == 1)
    #expect(fake.isRegistered == true)
}

@Test func enablingIsNoOpWhenAlreadyRegistered() throws {
    let fake = FakeLoginItem(registered: true)
    try LaunchAtLogin(control: fake).setEnabled(true)
    #expect(fake.registerCalls == 0)
}

@Test func disablingUnregistersWhenRegistered() throws {
    let fake = FakeLoginItem(registered: true)
    try LaunchAtLogin(control: fake).setEnabled(false)
    #expect(fake.unregisterCalls == 1)
    #expect(fake.isRegistered == false)
}

@Test func disablingIsNoOpWhenNotRegistered() throws {
    let fake = FakeLoginItem(registered: false)
    try LaunchAtLogin(control: fake).setEnabled(false)
    #expect(fake.unregisterCalls == 0)
}

@Test func setEnabledPropagatesErrors() {
    #expect(throws: ThrowingLoginItem.Failure.self) {
        try LaunchAtLogin(control: ThrowingLoginItem()).setEnabled(true)
    }
}
