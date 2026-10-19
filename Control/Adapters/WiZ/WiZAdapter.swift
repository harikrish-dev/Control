import Foundation
import Network
#if canImport(Darwin)
import Darwin
#endif

@MainActor
final class WiZAdapter {
    private let wizPort: UInt16 = 38899

    static func sendRawUDP(data: Data, to host: String, port: UInt16 = 38899) {
        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else { return }
        defer { close(sock) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        inet_pton(AF_INET, host, &addr.sin_addr)

        data.withUnsafeBytes { rawBuffer in
            guard let ptr = rawBuffer.baseAddress else { return }
            _ = withUnsafePointer(to: &addr) { sockaddrPtr in
                sockaddrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    sendto(sock, ptr, data.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }

    func sendCommand(_ command: DeviceCommand, to device: SmartDevice) async throws {
        let data: Data
        switch command {
        case .power(let on):
            data = WiZCommands.setPilot(on: on)
        case .brightness(let level):
            data = WiZCommands.setPilot(brightness: level)
        case .colorTemperature(let kelvin):
            data = WiZCommands.setPilot(colorTemp: kelvin)
        case .rgb(let r, let g, let b):
            data = WiZCommands.setPilot(r: r, g: g, b: b, brightness: device.brightness)
        case .scene(let sceneName):
            if let scene = WiZScenes.scenes.first(where: { $0.name == sceneName }) {
                data = WiZCommands.setPilot(sceneId: scene.id)
            } else { return }
        default: return
        }

        guard !device.ipAddress.isEmpty, device.ipAddress != "cloud" else {
            device.triggerUnreachableAlert(reason: "No IP address configured")
            throw NetworkError.deviceUnreachable("No IP address configured")
        }

        let host = device.ipAddress
        let port = wizPort

        // Send UDP command and verify response from the physical bulb
        let success = await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let sock = socket(AF_INET, SOCK_DGRAM, 0)
                guard sock >= 0 else {
                    continuation.resume(returning: false)
                    return
                }
                defer { close(sock) }

                var tv = timeval(tv_sec: 0, tv_usec: 700_000) // 700ms timeout
                setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

                var addr = sockaddr_in()
                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_port = port.bigEndian
                inet_pton(AF_INET, host, &addr.sin_addr)

                var bytesRead = 0
                var buf = [UInt8](repeating: 0, count: 2048)

                for _ in 0..<2 {
                    let sent = data.withUnsafeBytes { rawBuffer -> Int in
                        guard let ptr = rawBuffer.baseAddress else { return -1 }
                        return withUnsafePointer(to: &addr) { sockaddrPtr in
                            sockaddrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                                sendto(sock, ptr, data.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                            }
                        }
                    }
                    guard sent > 0 else { continue }
                    bytesRead = recv(sock, &buf, buf.count, 0)
                    if bytesRead > 0 { break }
                }

                continuation.resume(returning: bytesRead > 0)
            }
        }

        if !success {
            device.isOnline = false
            device.isOn = false
            device.triggerUnreachableAlert(reason: "Wall switch is OFF. Turn on switch to power light.")
            throw NetworkError.deviceUnreachable("Wall switch is OFF or light is disconnected")
        }

        device.isOnline = true
        device.unreachableAlertMessage = nil
        device.unreachableTrigger = nil
        switch command {
        case .power(let on): device.isOn = on
        case .brightness(let level): device.brightness = level; device.isOn = true
        case .colorTemperature(let kelvin): device.colorTemperature = kelvin; device.isOn = true
        case .rgb(let r, let g, let b): device.red = r; device.green = g; device.blue = b; device.isOn = true
        case .scene(let name): device.currentScene = name; device.isOn = true
        default: break
        }
    }

    func refreshState(_ device: SmartDevice) async {
        guard !device.ipAddress.isEmpty, device.ipAddress != "cloud" else { return }

        let port = wizPort
        let host = device.ipAddress

        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let sock = socket(AF_INET, SOCK_DGRAM, 0)
                guard sock >= 0 else {
                    DispatchQueue.main.async { continuation.resume() }
                    return
                }
                defer { close(sock) }

                var tv = timeval(tv_sec: 0, tv_usec: 750_000) // 750ms timeout
                setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

                var addr = sockaddr_in()
                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_port = port.bigEndian
                inet_pton(AF_INET, host, &addr.sin_addr)

                let msg = WiZCommands.getPilot()
                var bytesRead = 0
                var buf = [UInt8](repeating: 0, count: 2048)

                for _ in 0..<2 {
                    _ = msg.withUnsafeBytes { rawBuffer in
                        guard let ptr = rawBuffer.baseAddress else { return 0 }
                        return withUnsafePointer(to: &addr) { sockaddrPtr in
                            sockaddrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                                sendto(sock, ptr, msg.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                            }
                        }
                    }
                    bytesRead = recv(sock, &buf, buf.count, 0)
                    if bytesRead > 0 { break }
                }

                if bytesRead > 0 {
                    let data = Data(buf[0..<bytesRead])
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let result = json["result"] as? [String: Any] {
                        DispatchQueue.main.async {
                            let isRecent = Date().timeIntervalSince(device.lastActionDate) < 3.0
                            device.isOnline = true
                            device.unreachableAlertMessage = nil
                            device.unreachableTrigger = nil
                            if !isRecent {
                                if let state = result["state"] as? Bool {
                                    device.isOn = state
                                }
                                if let dimming = result["dimming"] as? Int {
                                    device.brightness = dimming
                                }
                                if let temp = result["temp"] as? Int {
                                    device.colorTemperature = temp
                                }
                                if let r = result["r"] as? Int, let g = result["g"] as? Int, let b = result["b"] as? Int {
                                    device.red = r; device.green = g; device.blue = b
                                }
                            }
                            device.lastSeen = Date()
                            continuation.resume()
                        }
                        return
                    }
                }
                DispatchQueue.main.async {
                    device.isOnline = false
                    device.isOn = false
                    continuation.resume()
                }
            }
        }
    }

    func discover() async -> [SmartDevice] {
        var devices: [SmartDevice] = []
        let scanned = await NetworkScanner.shared.scanLocalNetwork()
        let wizCandidates = scanned.filter { $0.brand == .wiz }

        for candidate in wizCandidates {
            let cleanMac = candidate.mac.replacingOccurrences(of: ":", with: "").lowercased()
            let dev = SmartDevice(
                id: "wiz_\(cleanMac.isEmpty ? candidate.ip.replacingOccurrences(of: ".", with: "_") : cleanMac)",
                name: "WiZ Light",
                brand: .wiz,
                type: .light,
                ipAddress: candidate.ip
            )
            dev.isOnline = false
            await refreshState(dev)
            devices.append(dev)
        }
        return devices
    }
}
