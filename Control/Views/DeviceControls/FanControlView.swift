import SwiftUI

struct FanControlView: View {
    @Bindable var device: SmartDevice
    var onCommand: (DeviceCommand) -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Speed Levels
            VStack(alignment: .leading, spacing: 12) {
                Text("Fan Speed")
                    .font(.headline)

                HStack(spacing: 8) {
                    ForEach(1...6, id: \.self) { speed in
                        Button {
                            HapticFeedback.snap()
                            device.speed = speed
                            device.isBoostMode = false
                            onCommand(.fanSpeed(speed))
                        } label: {
                            Text("\(speed)")
                                .font(.title3.bold())
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(device.speed == speed && !device.isBoostMode ? Color.blue : Color.secondary.opacity(0.1))
                                .foregroundColor(device.speed == speed && !device.isBoostMode ? .white : .primary)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(12)

            // Special Modes
            HStack(spacing: 12) {
                // Boost Mode
                Button {
                    HapticFeedback.click()
                    let newBoost = !device.isBoostMode
                    device.isBoostMode = newBoost
                    onCommand(.fanBoost(newBoost))
                } label: {
                    HStack {
                        Image(systemName: "bolt.fill")
                        Text("Boost Mode")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(device.isBoostMode ? Color.orange : Color.secondary.opacity(0.1))
                    .foregroundColor(device.isBoostMode ? .white : .primary)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                // Sleep Mode
                Button {
                    HapticFeedback.click()
                    let newSleep = !device.isSleepMode
                    device.isSleepMode = newSleep
                    onCommand(.fanSleep(newSleep))
                } label: {
                    HStack {
                        Image(systemName: "moon.fill")
                        Text("Sleep Mode")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(device.isSleepMode ? Color.indigo : Color.secondary.opacity(0.1))
                    .foregroundColor(device.isSleepMode ? .white : .primary)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }

            // LED Toggle
            Toggle(isOn: Binding(
                get: { device.isLedOn },
                set: { val in
                    HapticFeedback.click()
                    device.isLedOn = val
                    onCommand(.fanLed(val))
                }
            )) {
                Label("Status LED", systemImage: "lightbulb")
                    .font(.headline)
            }
            .padding()
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(12)
        }
    }
}
