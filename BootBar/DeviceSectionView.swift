import SwiftUI
import BootBarCore

struct DeviceSectionView: View {
    let title: String
    let devices: [Device]
    let error: String?
    let busyDeviceIds: Set<String>
    let rowErrors: [String: String]
    let onAction: (DeviceAction, Device) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader
            if let error {
                errorLabel(error)
            } else if devices.isEmpty {
                emptyLabel
            } else {
                deviceGroup
            }
        }
    }

    private var sectionHeader: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.5)
            Spacer()
            Text(runningSummary)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
    }

    private var runningSummary: String {
        "\(devices.count(where: { $0.state == .running })) of \(devices.count) running"
    }

    private var deviceGroup: some View {
        VStack(spacing: 0) {
            ForEach(devices) { device in
                if device.id != devices.first?.id {
                    Divider()
                }
                DeviceRowView(
                    device: device,
                    isBusy: busyDeviceIds.contains(device.id),
                    error: rowErrors[device.id],
                    onAction: { onAction($0, device) })
            }
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator, lineWidth: 1))
    }

    private func errorLabel(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
    }

    private var emptyLabel: some View {
        Text("No devices found")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
    }
}
