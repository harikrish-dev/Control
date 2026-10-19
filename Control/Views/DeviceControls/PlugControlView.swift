import SwiftUI

struct PlugControlView: View {
    @Bindable var device: SmartDevice
    var onCommand: ((DeviceCommand) -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            // Master Switch Banner
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.isPowerStrip ? "Smart Power Strip (4 Sockets)" : "Smart Plug")
                        .font(.headline)
                    Text(device.isOn ? "Master: All Sockets Active" : "Master: Switched Off")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                PowerButton(isOn: device.isOn) {
                    let newState = !device.isOn
                    device.setAllSocketsOptimistic(isOn: newState)
                    onCommand?(.power(newState))
                }
            }
            .padding()
            .background(Color.green.opacity(0.1))
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
                            onToggle: {
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
                    value: device.currentVoltage != nil ? String(format: "%.1f V", device.currentVoltage!) : "— V",
                    icon: "gauge"
                )
                MetricCard(
                    title: "Total Load",
                    value: device.currentPower != nil ? String(format: "%.1f W", device.currentPower!) : (device.isOn ? "— W" : "0.0 W"),
                    icon: "bolt.fill"
                )
                MetricCard(
                    title: "Current",
                    value: device.currentCurrent != nil ? String(format: "%.2f A", device.currentCurrent!) : (device.isOn ? "— A" : "0.00 A"),
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
    let onToggle: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isOn ? Color.green : Color.secondary.opacity(0.3))
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

            Button(action: onToggle) {
                Image(systemName: "power")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isOn ? .white : .secondary)
                    .frame(width: 30, height: 30)
                    .background(isOn ? Color.green : Color.secondary.opacity(0.15))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .focusable(false)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
}
