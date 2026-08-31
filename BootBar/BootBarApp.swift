import SwiftUI
import BootBarCore

@main
struct BootBarApp: App {
    @State private var viewModel = DeviceListViewModel {
        SDKLocator(override: UserDefaults.standard.string(forKey: "androidSdkPath")).locate()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanelView()
                .environment(viewModel)
                .frame(width: 340, height: 560)
        } label: {
            Image(nsImage: MenuBarIcon.image(count: viewModel.runningCount))
                .task { viewModel.startWatchingDevices() }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
