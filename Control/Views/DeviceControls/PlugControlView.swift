import SwiftUI

struct PlugControlView: View {
    @Bindable var device: SmartDevice
    var onCommand: ((DeviceCommand) -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            // Offline Warning Banner
            if !device.isOnline {
                HStack(spacing: 10) {
                    Image(systemName: device.unreachableIcon)
                        .font(.title3.bold())
                        .foregroundColor(device.unreachableColor)
                        .symbolEffect(.bounce, value: device.unreachableTrigger)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.unreachableTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(device.unreachableSubtitle)
                            .font(.caption)
                            .foregroundColor(Color.white.opacity(0.85))
                    }
                    Spacer()
                }
                .padding(14)
                .background(Color(red: 0.16, green: 0.08, blue: 0.10))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(device.unreachableColor.opacity(0.6), lineWidth: 1.2)
                )
            }

            // Master Switch Banner
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.isPowerStrip ? "Smart Power Strip (4 Sockets)" : "Smart Plug")
                        .font(.headline)
                    Text(!device.isOnline ? "Strip Offline (Main Switch is OFF)" : (device.isOn ? "Master: All Sockets Active" : "Master: Switched Off"))
                        .font(.caption)
                        .foregroundColor(!device.isOnline ? device.unreachableColor : .secondary)
                }
                Spacer()
                PowerButton(isOn: device.isOnline && device.isOn) {
                    if !device.isOnline {
                        device.triggerUnreachableAlert()
                        return
                    }
                    let newState = !device.isOn
                    device.setAllSocketsOptimistic(isOn: newState)
                    onCommand?(.power(newState))
                }
            }
            .padding()
            .background((device.isOnline && device.isOn) ? Color.green.opacity(0.1) : Color.secondary.opacity(0.08))
            .cornerRadius(14)

            // 4 Individual Sockets Grid
            VStack(alignment: .leading, spacing: 12) {
                Text("Individual Sockets")
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(0..<min(device.socketCount, device.socketStates.count), id: \.self) { idx in
                        SocketCard(
                            socketIndex: idx + 1,
                            name: idx < device.socketNames.count ? device.socketNames[idx] : "Socket \(idx + 1)",
                            isOn: device.socketStates[idx],
                            isOnline: device.isOnline,
                            onToggle: {
                                if !device.isOnline {
                                    device.triggerUnreachableAlert()
                                    return
                                }
                                HapticFeedback.click()
                                let newState = !device.socketStates[idx]
                                device.setSocketStateOptimistic(socketIndex: idx + 1, isOn: newState)
                                onCommand?(.socketPower(socketIndex: idx + 1, isOn: newState))
                            }
                        )
                    }
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(16)

            // Real Live Electrical Telemetry Metrics
            HStack(spacing: 12) {
                MetricCard(
                    title: "Voltage",
                    value: (device.isOnline && device.currentVoltage != nil) ? String(format: "%.1f V", device.currentVoltage!) : "— V",
                    icon: "gauge"
                )
                MetricCard(
                    title: "Total Load",
                    value: (device.isOnline && device.currentPower != nil) ? String(format: "%.1f W", device.currentPower!) : (device.isOn ? "— W" : "0.0 W"),
                    icon: "bolt.fill"
                )
                MetricCard(
                    title: "Current",
                    value: (device.isOnline && device.currentCurrent != nil) ? String(format: "%.2f A", device.currentCurrent!) : (device.isOn ? "— A" : "0.00 A"),
                    icon: "waveform.path.ecg"
                )
            }
        }
    }
}

struct SocketCard: View {
    let socketIndex: Int
    let name: String
    let isOn: Bool
    var isOnline: Bool = true
    let onToggle: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(!isOnline ? Color.secondary.opacity(0.3) : (isOn ? Color.green : Color.secondary.opacity(0.3)))
                        .frame(width: 8, height: 8)
                    Text("Socket \(socketIndex)")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                }

                Text(name)
                    .font(.subheadline.bold())
                    .lineLimit(1)
            }

            Spacer()

            PowerButton(isOn: isOnline && isOn, action: onToggle)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke((isOnline && isOn) ? Color.green.opacity(0.4) : Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(12)
    }
}
