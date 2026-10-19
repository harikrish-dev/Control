import SwiftUI

struct DeviceCardView: View {
    @Bindable var device: SmartDevice
    var onToggle: () -> Void
    var onTap: () -> Void
    var onDelete: () -> Void

    @State private var isCardHovered: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    HapticFeedback.click()
                    onToggle()
                } label: {
                    DeviceIconView(device: device, size: 38)
                }
                .buttonStyle(.plain)
                .focusable(false)

                Spacer()

                PowerButton(isOn: device.isOn, action: onToggle)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack {
                    Text(device.brand.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(device.brand.color.opacity(0.15))
                        .foregroundColor(device.brand.color)
                        .cornerRadius(4)

                    Text(device.statusText)
                        .font(.caption.bold())
                        .foregroundColor(device.isOn ? .primary : .secondary)
                }
            }
        }
        .padding(14)
        .frame(minWidth: 160, minHeight: 120)
        .background(
            DeviceAnimatedBackground(device: device, cornerRadius: 14, isDarkTheme: false, isHovered: isCardHovered)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(device.isOn ? device.brand.color.opacity(0.4) : Color.primary.opacity(0.06), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle())
        .onHover { hovering in
            isCardHovered = hovering
        }
        .onTapGesture {
            HapticFeedback.click()
            onTap()
        }
        .contextMenu {
            Button {
                onTap()
            } label: {
                Label("Open Controls", systemImage: "slider.horizontal.3")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Remove Device", systemImage: "trash")
            }
        }
    }
}
