import SwiftUI

struct ACControlView: View {
    @Bindable var device: SmartDevice
    var onCommand: (DeviceCommand) -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Temperature Display & Stepper
            VStack(spacing: 8) {
                Text("Target Temperature")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 30) {
                    Button {
                        HapticFeedback.snap()
                        if device.targetTemperature > 16.0 {
                            device.targetTemperature -= 0.5
                            onCommand(.acTemperature(device.targetTemperature))
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)

                    VStack {
                        Text(String(format: "%.1f°C", device.targetTemperature))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan)

                        if let indoor = device.indoorTemperature {
                            Text(String(format: "Room: %.1f°C", indoor))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Button {
                        HapticFeedback.snap()
                        if device.targetTemperature < 30.0 {
                            device.targetTemperature += 0.5
                            onCommand(.acTemperature(device.targetTemperature))
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.cyan)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.cyan.opacity(0.08))
            .cornerRadius(16)

            // AC Modes
            VStack(alignment: .leading, spacing: 8) {
                Text("Mode")
                    .font(.headline)
                HStack(spacing: 8) {
                    ForEach(ACMode.allCases) { mode in
                        Button {
                            HapticFeedback.snap()
                            device.acMode = mode
                            onCommand(.acMode(mode))
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: mode.icon)
                                Text(mode.displayName)
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(device.acMode == mode ? Color.cyan : Color.secondary.opacity(0.1))
                            .foregroundColor(device.acMode == mode ? .white : .primary)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(12)

            // Flexicool Convertible Modes
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("AI Flexicool Convertible", systemImage: "sparkles")
                        .font(.headline)
                    Spacer()
                    Text("Carrier Eco Tech")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    ForEach(FlexicoolLevel.allCases) { level in
                        Button {
                            HapticFeedback.snap()
                            device.flexicoolLevel = level
                            onCommand(.acFlexicool(level))
                        } label: {
                            Text(level.displayName)
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(device.flexicoolLevel == level ? Color.green : Color.secondary.opacity(0.1))
                                .foregroundColor(device.flexicoolLevel == level ? .white : .primary)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(12)

            // Quick Toggles: Swing, Turbo, Eco
            HStack(spacing: 10) {
                ToggleOption(title: "Swing", icon: "arrow.up.and.down", isOn: device.isSwingOn) {
                    device.isSwingOn.toggle()
                    onCommand(.acSwing(device.isSwingOn))
                }
                ToggleOption(title: "Turbo", icon: "bolt.fill", isOn: device.isTurbo) {
                    device.isTurbo.toggle()
                    if device.isTurbo { device.isEco = false }
                    onCommand(.acTurbo(device.isTurbo))
                }
                ToggleOption(title: "ECO", icon: "leaf.fill", isOn: device.isEco) {
                    device.isEco.toggle()
                    if device.isEco { device.isTurbo = false }
                    onCommand(.acEco(device.isEco))
                }
            }
        }
    }
}

struct ToggleOption: View {
    let title: String
    let icon: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button {
            HapticFeedback.click()
            action()
        } label: {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline.bold())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isOn ? Color.accentColor : Color.secondary.opacity(0.1))
            .foregroundColor(isOn ? .white : .primary)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}
