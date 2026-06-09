import SwiftUI

struct SettingsView: View {
    @AppStorage("androidSdkPath") private var androidSdkPath = ""
    @State private var launchModel = LaunchAtLoginModel()

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchModel.isEnabled },
                    set: { launchModel.set($0) }
                ))
                if let message = launchModel.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                TextField("Android SDK Path", text: $androidSdkPath,
                          prompt: Text("/Users/you/Library/Android/sdk"))
                Text("Leave empty to auto-detect from $ANDROID_HOME, $ANDROID_SDK_ROOT, or ~/Library/Android/sdk.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize()
        .onAppear { launchModel.refresh() }
    }
}
