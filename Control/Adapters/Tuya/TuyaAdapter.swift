import Foundation
import Network

@MainActor
final class TuyaAdapter {
    func sendCommand(_ command: DeviceCommand, to device: SmartDevice) async throws {
        // Send via TuyaCloudBridge using the configured device virtual ID
        guard !device.tuyaDeviceId.isEmpty else {
            device.triggerUnreachableAlert(reason: "Power strip device ID is empty")
            return
        }
        let devId = device.tuyaDeviceId

        switch command {
        case .socketPower(let socketIndex, let isOn):
            device.setSocketStateOptimistic(socketIndex: socketIndex, isOn: isOn)
            let success = await TuyaCloudBridge.shared.setSocketPower(deviceId: devId, socketIndex: socketIndex, isOn: isOn)
            if !success {
                device.isOnline = false
                device.isOn = false
                for i in 0..<device.socketStates.count {
                    device.socketStates[i] = false
                }
                device.triggerUnreachableAlert(reason: "Power strip is offline or main switch is OFF")
                throw NetworkError.deviceUnreachable("Power strip is unreachable")
            } else {
                device.isOnline = true
                device.unreachableAlertMessage = nil
                device.unreachableTrigger = nil
            }

        case .power(let on):
            device.setAllSocketsOptimistic(isOn: on)
            let success = await TuyaCloudBridge.shared.setAllSocketsPower(deviceId: devId, isOn: on)
            if !success {
                device.isOnline = false
                device.isOn = false
                for i in 0..<device.socketStates.count {
                    device.socketStates[i] = false
                }
                device.triggerUnreachableAlert(reason: "Power strip is offline or main switch is OFF")
                throw NetworkError.deviceUnreachable("Power strip is unreachable")
            } else {
                device.isOnline = true
                device.unreachableAlertMessage = nil
                device.unreachableTrigger = nil
            }

        default:
            break
        }
    }
}
