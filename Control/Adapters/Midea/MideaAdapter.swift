import Foundation
import Network

@MainActor
final class MideaAdapter {
    func sendCommand(_ command: DeviceCommand, to device: SmartDevice) async throws {
        var power = device.isOn, temperature = device.targetTemperature, mode = device.acMode
        var fanSpeed = device.acFanSpeed, swing = device.isSwingOn, turbo = device.isTurbo, eco = device.isEco
        var flex = device.flexicoolLevel

        switch command {
        case .power(let on): power = on
        case .acTemperature(let t): temperature = t; power = true
        case .acMode(let m): mode = m; power = true
        case .acFanSpeed(let s): fanSpeed = s; power = true
        case .acSwing(let on): swing = on
        case .acTurbo(let on): turbo = on; eco = false
        case .acEco(let on): eco = on; turbo = false
        case .acFlexicool(let f): flex = f
        default: return
        }

        if !device.ipAddress.isEmpty && device.ipAddress != "demo" {
            let cmdData = MideaProtocol.buildControlCommand(power: power, temperature: temperature, mode: mode,
                                                            fanSpeed: fanSpeed, swing: swing, turbo: turbo, eco: eco)
            let tcp = TCPConnection(host: device.ipAddress, port: 6444)
            if (try? await tcp.connect()) != nil {
                _ = try? await tcp.send(cmdData)
                await tcp.disconnect()
            }
        }

        device.isOn = power
        device.targetTemperature = temperature
        device.acMode = mode
        device.acFanSpeed = fanSpeed
        device.isSwingOn = swing
        device.isTurbo = turbo
        device.isEco = eco
        device.flexicoolLevel = flex
    }
}
