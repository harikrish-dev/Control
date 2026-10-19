import Foundation
import Network

@MainActor
final class TuyaAdapter {
    func sendCommand(_ command: DeviceCommand, to device: SmartDevice) async throws {
        // Send via TuyaCloudBridge using the configured device virtual ID
        guard !device.tuyaDeviceId.isEmpty else {
            print("TuyaAdapter: tuyaDeviceId is empty for \(device.name)")
            return
        }
        let devId = device.tuyaDeviceId

        switch command {
        case .socketPower(let socketIndex, let isOn):
            device.setSocketStateOptimistic(socketIndex: socketIndex, isOn: isOn)
            _ = await TuyaCloudBridge.shared.setSocketPower(deviceId: devId, socketIndex: socketIndex, isOn: isOn)
        case .power(let on):
            device.setAllSocketsOptimistic(isOn: on)
            _ = await TuyaCloudBridge.shared.setAllSocketsPower(deviceId: devId, isOn: on)
        default:
            break
        }
    }
}
