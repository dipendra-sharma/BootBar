import SwiftUI
import BootBarCore

@main
struct BootBarApp: App {
    @State private var viewModel = DeviceListViewModel {
        SDKLocator(override: UserDefaults.standard.string(forKey: "androidSdkPath")).locate()
    }

    var body: some Scene {
        MenuBarExtra("BootBar", systemImage: "iphone.gen3") {
            MenuBarPanelView()
                .environment(viewModel)
                .frame(width: 340, height: 560)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
