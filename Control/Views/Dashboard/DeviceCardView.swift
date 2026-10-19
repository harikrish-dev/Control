import SwiftUI

struct DeviceCardView: View {
    @Bindable var device: SmartDevice
    var onToggle: () -> Void
    var onTap: () -> Void
    var onDelete: () -> Void

    @State private var isCardHovered: Bool = false
    @State private var isRenaming: Bool = false
    @State private var editedName: String = ""
    @FocusState private var isNameFocused: Bool
    @State private var isNameHovered: Bool = false
    @State private var shakeOffset: CGFloat = 0

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

            VStack(alignment: .leading, spacing: 5) {
                if isRenaming {
                    HStack(spacing: 4) {
                        TextField("Name", text: $editedName)
                            .font(.system(size: 13, weight: .bold))
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.9))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(device.brand.color.opacity(0.7), lineWidth: 1)
                            )
                            .focused($isNameFocused)
                            .onSubmit {
                                commitRename()
                            }
                            .onExitCommand {
                                isRenaming = false
                            }

                        Button {
                            commitRename()
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                        }
                        .buttonStyle(.plain)

                        Button {
                            isRenaming = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    HStack(spacing: 5) {
                        Text(device.name)
                            .font(.headline)
                            .lineLimit(1)
                            .underline(isNameHovered, color: device.brand.color.opacity(0.5))

                        if isNameHovered {
                            Image(systemName: "pencil")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(device.brand.color)
                                .transition(.opacity)
                        }
                    }
                    .contentShape(Rectangle())
                    .onHover { isNameHovered = $0 }
                    .onTapGesture {
                        startRename()
                    }
                    .help("Click to rename this device")
                }

                HStack(spacing: 6) {
                    Text(device.brand.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(device.brand.color.opacity(0.15))
                        .foregroundColor(device.brand.color)
                        .cornerRadius(4)

                    if !device.isOnline {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(device.unreachableColor)
                                .frame(width: 5, height: 5)

                            Text(device.statusText)
                                .font(.caption2.bold())
                                .foregroundColor(device.unreachableColor)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(device.unreachableColor.opacity(0.12))
                        .cornerRadius(4)
                    } else {
                        Text(device.statusText)
                            .font(.caption.bold())
                            .foregroundColor(device.isOn ? .primary : .secondary)
                    }
                }
            }
        }
        .padding(14)
        .frame(minWidth: 160, minHeight: 120)
        .offset(x: shakeOffset)
        .background(
            DeviceAnimatedBackground(device: device, cornerRadius: 14, isDarkTheme: false, isHovered: isCardHovered)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    !device.isOnline
                        ? device.unreachableColor.opacity(0.35)
                        : (device.isOn ? device.brand.color.opacity(0.4) : Color.primary.opacity(0.06)),
                    lineWidth: 1.2
                )
        )
        .overlay(alignment: .center) {
            if let alertMsg = device.unreachableAlertMessage {
                unreachableBanner(msg: alertMsg)
            }
        }
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle())
        .onHover { hovering in
            isCardHovered = hovering
        }
        .onTapGesture {
            if !isRenaming {
                HapticFeedback.click()
                onTap()
            }
        }
        .onChange(of: device.unreachableTrigger) { _, _ in
            triggerShakeAnimation()
        }
        .contextMenu {
            Button {
                startRename()
            } label: {
                Label("Rename Device", systemImage: "pencil")
            }

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

    private func startRename() {
        editedName = device.name
        isRenaming = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isNameFocused = true
        }
    }

    private func commitRename() {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != device.name {
            device.name = trimmed
            DeviceManager.shared.saveDevices()
            HapticFeedback.snap()
        }
        isRenaming = false
    }

    private func triggerShakeAnimation() {
        withAnimation(.spring(response: 0.10, dampingFraction: 0.2)) {
            shakeOffset = 7
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.spring(response: 0.10, dampingFraction: 0.2)) {
                shakeOffset = -7
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            withAnimation(.spring(response: 0.12, dampingFraction: 0.25)) {
                shakeOffset = 5
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
                shakeOffset = 0
            }
        }
    }

    @ViewBuilder
    private func unreachableBanner(msg: String) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: device.unreachableIcon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(device.unreachableColor)
                    .symbolEffect(.bounce, value: device.unreachableTrigger)

                Text(device.unreachableTitle)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }

            Text(msg)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundColor(Color.white.opacity(0.92))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color(red: 0.11, green: 0.08, blue: 0.09).opacity(0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(device.unreachableColor.opacity(0.85), lineWidth: 1.2)
        )
        .shadow(color: device.unreachableColor.opacity(0.4), radius: 8, x: 0, y: 3)
        .padding(6)
        .transition(.scale(scale: 0.88).combined(with: .opacity))
    }
}
