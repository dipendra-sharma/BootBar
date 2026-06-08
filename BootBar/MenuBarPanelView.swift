import SwiftUI
import AppKit
import Combine
import BootBarCore

struct MenuBarPanelView: View {
    @Environment(DeviceListViewModel.self) private var viewModel
    @Environment(\.openSettings) private var openSettings
    @Environment(\.scenePhase) private var scenePhase

    private let appLaunched = NSWorkspace.shared.notificationCenter
        .publisher(for: NSWorkspace.didLaunchApplicationNotification)
    private let appTerminated = NSWorkspace.shared.notificationCenter
        .publisher(for: NSWorkspace.didTerminateApplicationNotification)

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            deviceList
            Divider()
            footer
        }
        .task { await autoRefresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await viewModel.refresh() } }
        }
        .onReceive(appLaunched) { refreshIfDeviceHost($0) }
        .onReceive(appTerminated) { refreshIfDeviceHost($0) }
    }

    private var header: some View {
        HStack {
            Label("BootBar", systemImage: "iphone")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var deviceList: some View {
        ScrollView {
            VStack(spacing: 14) {
                DeviceSectionView(
                    title: "IOS SIMULATORS",
                    devices: viewModel.iosDevices,
                    error: viewModel.iosError,
                    busyDeviceIds: viewModel.busyDeviceIds,
                    rowErrors: viewModel.rowErrors,
                    onAction: performAction)
                DeviceSectionView(
                    title: "ANDROID EMULATORS",
                    devices: viewModel.androidDevices,
                    error: viewModel.androidError,
                    busyDeviceIds: viewModel.busyDeviceIds,
                    rowErrors: viewModel.rowErrors,
                    onAction: performAction)
            }
            .padding(10)
        }
    }

    private var footer: some View {
        HStack {
            Button {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            Spacer()
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func performAction(_ action: DeviceAction, on device: Device) {
        Task { await viewModel.perform(action, on: device) }
    }

    private func autoRefresh() async {
        while !Task.isCancelled {
            await viewModel.refresh()
            try? await Task.sleep(for: .seconds(5))
        }
    }

    private func refreshIfDeviceHost(_ notification: Notification) {
        guard isDeviceHost(notification) else { return }
        Task { await viewModel.refresh() }
    }

    private func isDeviceHost(_ notification: Notification) -> Bool {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return false
        }
        if app.bundleIdentifier == "com.apple.iphonesimulator" { return true }
        let executable = app.executableURL?.lastPathComponent ?? app.localizedName ?? ""
        return executable.contains("qemu") || executable.contains("emulator")
    }
}
