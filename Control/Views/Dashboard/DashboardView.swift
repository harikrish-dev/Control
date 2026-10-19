import SwiftUI

struct DashboardView: View {
    @Bindable var manager: DeviceManager
    @State private var selectedBrand: DeviceBrand? = nil

    var filteredDevices: [SmartDevice] {
        if let brand = selectedBrand {
            return manager.devices.filter { $0.brand == brand }
        }
        return manager.devices
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Quick Summary Banner
                HStack(spacing: 16) {
                    SummaryTile(
                        title: "Active Devices",
                        value: "\(manager.devices.filter { $0.isOn }.count)/\(manager.devices.count)",
                        icon: "power.circle.fill",
                        color: .green
                    )
                    SummaryTile(
                        title: "Carrier AC",
                        value: manager.devices.first(where: { $0.brand == .carrier && $0.isOn }).map { String(format: "%.0f°C", $0.targetTemperature) } ?? "Off",
                        icon: "snowflake",
                        color: .cyan
                    )
                    SummaryTile(
                        title: "Atomberg Fan",
                        value: manager.devices.first(where: { $0.brand == .atomberg && $0.isOn }).map { "Spd \($0.speed)" } ?? "Off",
                        icon: "fan.fill",
                        color: .blue
                    )
                }

                // Brand Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterPill(title: "All Devices", isSelected: selectedBrand == nil) {
                            selectedBrand = nil
                        }
                        ForEach(DeviceBrand.allCases) { brand in
                            FilterPill(title: brand.rawValue, isSelected: selectedBrand == brand) {
                                selectedBrand = brand
                            }
                        }
                    }
                }

                // Devices Grid
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(selectedBrand == nil ? "My Devices" : "\(selectedBrand!.rawValue) Devices")
                            .font(.title3.bold())

                        Spacer()

                        MuteButton()

                        SyncButton(manager: manager, showTitle: true)
                    }

                    if filteredDevices.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "house.and.flag")
                                .font(.system(size: 38))
                                .foregroundColor(.secondary.opacity(0.4))
                            Text("No Devices Connected")
                                .font(.headline)
                            Text("Click Add Device (+) in the toolbar or scan your local Wi-Fi to connect your lights, fans, plugs, or AC.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 320)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
                            ForEach(filteredDevices) { device in
                                DeviceCardView(device: device) {
                                    manager.toggleDevice(device)
                                } onTap: {
                                    manager.selectedDevice = device
                                } onDelete: {
                                    manager.removeDevice(device)
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .sheet(item: $manager.selectedDevice) { device in
            DeviceDetailSheet(device: device) { command in
                manager.sendCommand(command, to: device)
            } onDelete: {
                manager.removeDevice(device)
            }
        }
    }
}

struct SummaryTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title3.bold())
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
    }
}

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}
