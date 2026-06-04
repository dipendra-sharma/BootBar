import SwiftUI
import BootBarCore

struct DeviceRowView: View {
    let device: Device
    let isBusy: Bool
    let error: String?
    let onAction: (DeviceAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 9) {
                Circle().fill(stateColor).frame(width: 8, height: 8)
                deviceInfo
                Spacer(minLength: 8)
                trailing
            }
            if let error {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
    }

    private var deviceInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(device.name).font(.system(size: 13, weight: .medium))
            Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }

    private var subtitle: String {
        "\(device.osVersion) · \(stateLabel)"
    }

    private var stateLabel: String {
        switch device.state {
        case .running: "Running"
        case .booting: "Booting…"
        case .stopped: "Stopped"
        }
    }

    private var stateColor: Color {
        switch device.state {
        case .running: .green
        case .booting: .orange
        case .stopped: Color(nsColor: .tertiaryLabelColor)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if isBusy {
            ProgressView().controlSize(.small)
        } else {
            primaryActionButton
            actionMenu
        }
    }

    private var primaryActionButton: some View {
        Button {
            onAction(device.state == .running ? .stop : .start)
        } label: {
            Image(systemName: device.state == .running ? "stop.fill" : "play.fill")
                .foregroundStyle(device.state == .booting ? Color.secondary : (device.state == .running ? Color.red : Color.blue))
        }
        .buttonStyle(.plain)
        .frame(width: 24, height: 24)
        .disabled(device.state == .booting)
    }

    private var actionMenu: some View {
        Menu {
            Button("Cold Boot") { onAction(.coldBoot) }
            Button(device.platform == .ios ? "Erase" : "Wipe Data", role: .destructive) {
                onAction(.erase)
            }
        } label: {
            Image(systemName: "ellipsis").foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 24, height: 24)
    }
}
