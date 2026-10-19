import SwiftUI

struct RoomsView: View {
    @Bindable var manager: DeviceManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(manager.rooms) { room in
                    roomSection(room: room)
                }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func roomSection(room: Room) -> some View {
        let roomDevices = manager.devices.filter { $0.roomId == room.id }

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(room.name, systemImage: room.icon)
                    .font(.title3.bold())
                Spacer()
                Button("All Off") {
                    for dev in roomDevices {
                        manager.sendCommand(.power(false), to: dev)
                    }
                }
                .font(.caption)
            }

            if roomDevices.isEmpty {
                Text("No devices in this room.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
                    ForEach(roomDevices) { device in
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
        .padding()
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .cornerRadius(16)
    }
}
