import SwiftUI

struct SettingsView: View {
    @AppStorage("androidSdkPath") private var androidSdkPath = ""

    var body: some View {
        Form {
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
    }
}
