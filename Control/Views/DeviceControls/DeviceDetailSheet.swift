import SwiftUI

struct DeviceDetailSheet: View {
    @Bindable var device: SmartDevice
    var onCommand: (DeviceCommand) -> Void
    var onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showConfirmDelete = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: device.type.icon)
                        .font(.title)
                        .foregroundColor(device.brand.color)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.name)
                            .font(.title2.bold())
                        Text("\(device.brand.rawValue) · \(device.ipAddress)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                PowerButton(isOn: device.isOn) {
                    onCommand(.power(!device.isOn))
                }
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
            .padding()
            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    switch device.type {
                    case .light:
                        LightControlView(device: device, onCommand: onCommand)
                    case .fan:
                        FanControlView(device: device, onCommand: onCommand)
                    case .airConditioner:
                        ACControlView(device: device, onCommand: onCommand)
                    case .plug:
                        PlugControlView(device: device, onCommand: onCommand)
                    }

                    Divider()
                        .padding(.top, 10)

                    // Delete / Remove Device Button
                    Button(role: .destructive) {
                        showConfirmDelete = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Remove Device from Control")
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .confirmationDialog(
                        "Remove \(device.name)?",
                        isPresented: $showConfirmDelete,
                        titleVisibility: .visible
                    ) {
                        Button("Remove", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will remove the device from your Control app dashboard.")
                    }
                }
                .padding()
            }
        }
        .frame(width: 480, height: 600)
    }
}
