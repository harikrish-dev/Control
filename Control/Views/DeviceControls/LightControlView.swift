import SwiftUI

struct LightControlView: View {
    @Bindable var device: SmartDevice
    var onCommand: (DeviceCommand) -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Brightness bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Brightness", systemImage: "sun.max.fill")
                        .font(.headline)
                    Spacer()
                    Text("\(device.brightness)%")
                        .font(.title3.monospacedDigit().bold())
                }
                Slider(value: Binding(
                    get: { Double(device.brightness) },
                    set: { val in
                        let intVal = Int(val)
                        if abs(intVal - device.brightness) >= 2 {
                            HapticFeedback.levelChange()
                        }
                        device.brightness = intVal
                        onCommand(.brightness(intVal))
                    }
                ), in: 10...100, step: 1)
                .tint(.yellow)
            }
            .padding()
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(12)

            // Color Temperature bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Color Temperature", systemImage: "thermometer.medium")
                        .font(.headline)
                    Spacer()
                    Text("\(device.colorTemperature)K")
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(
                    get: { Double(device.colorTemperature) },
                    set: { val in
                        let intVal = Int(val)
                        if abs(intVal - device.colorTemperature) >= 80 {
                            HapticFeedback.levelChange()
                        }
                        device.colorTemperature = intVal
                        onCommand(.colorTemperature(intVal))
                    }
                ), in: 2200...6500, step: 50)
                .tint(.orange)
            }
            .padding()
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(12)

            // Preset scenes
            VStack(alignment: .leading, spacing: 12) {
                Text("WiZ Mood Scenes")
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                    ForEach(WiZScenes.scenes.prefix(8), id: \.id) { scene in
                        Button {
                            HapticFeedback.snap()
                            device.currentScene = scene.name
                            onCommand(.scene(scene.name))
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: scene.icon)
                                    .font(.title3)
                                Text(scene.name)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(device.currentScene == scene.name ? Color.yellow.opacity(0.2) : Color.secondary.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(device.currentScene == scene.name ? Color.yellow : Color.clear, lineWidth: 1.5)
                            )
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
