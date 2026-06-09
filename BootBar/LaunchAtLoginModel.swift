import SwiftUI
import BootBarCore

@MainActor
@Observable
final class LaunchAtLoginModel {
    private(set) var isEnabled: Bool
    private(set) var errorMessage: String?
    private let launch: LaunchAtLogin

    init(launch: LaunchAtLogin = LaunchAtLogin()) {
        self.launch = launch
        self.isEnabled = launch.isEnabled
    }

    func refresh() {
        isEnabled = launch.isEnabled
        errorMessage = nil
    }

    func set(_ enabled: Bool) {
        do {
            try launch.setEnabled(enabled)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isEnabled = launch.isEnabled
    }
}
