import Foundation
import Network

@MainActor
final class AtombergLocalAdapter {
    static let shared = AtombergLocalAdapter()

    private let commandPort: UInt16 = 5600
    private let beaconPort: UInt16 = 5625

    private(set) var lastDiscoveredDevices: [SmartDevice] = []

    private init() {}

    // MARK: - Local Reachability Probe

    func checkLocalReachability(ip: String, mac: String = "") async -> Bool {
        guard !ip.isEmpty, ip.lowercased() != "cloud" else { return false }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let sock = socket(AF_INET, SOCK_DGRAM, 0)
                guard sock >= 0 else {
                    continuation.resume(returning: self.checkArpFallback(ip: ip, mac: mac))
                    return
                }
                defer { close(sock) }

                var opt: Int32 = 1
                setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int32>.size))
                setsockopt(sock, SOL_SOCKET, SO_REUSEPORT, &opt, socklen_t(MemoryLayout<Int32>.size))

                // 2.5s timeout (captures at least two 1.0s beacon intervals with room for Wi-Fi jitter)
                var tv = timeval(tv_sec: 2, tv_usec: 500_000)
                setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

                var bindAddr = sockaddr_in()
                bindAddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                bindAddr.sin_family = sa_family_t(AF_INET)
                bindAddr.sin_port = UInt16(5625).bigEndian
                bindAddr.sin_addr.s_addr = INADDR_ANY

                let bindRes = withUnsafePointer(to: &bindAddr) { saPtr in
                    saPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                        bind(sock, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
                guard bindRes == 0 else {
                    continuation.resume(returning: self.checkArpFallback(ip: ip, mac: mac))
                    return
                }

                var fromAddr = sockaddr_in()
                var fromLen = socklen_t(MemoryLayout<sockaddr_in>.size)
                var buf = [UInt8](repeating: 0, count: 1024)

                let bytes = withUnsafeMutablePointer(to: &fromAddr) { saPtr in
                    saPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                        recvfrom(sock, &buf, buf.count, 0, sa, &fromLen)
                    }
                }

                if bytes > 0 {
                    var ipBuf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                    inet_ntop(AF_INET, &fromAddr.sin_addr, &ipBuf, socklen_t(INET_ADDRSTRLEN))
                    let senderIP = String(cString: ipBuf)
                    let payload = (String(bytes: buf[0..<bytes], encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let targetMac = mac.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let match = senderIP == ip || (!targetMac.isEmpty && payload == targetMac) || ip.isEmpty
                    continuation.resume(returning: match)
                } else {
                    continuation.resume(returning: self.checkArpFallback(ip: ip, mac: mac))
                }
            }
        }
    }

    private nonisolated func checkArpFallback(ip: String, mac: String) -> Bool {
        guard !ip.isEmpty, ip.lowercased() != "cloud" else { return false }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/arp")
        proc.arguments = ["-n", ip]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
            guard proc.terminationStatus == 0 else { return false }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let out = String(data: data, encoding: .utf8)?.lowercased() else { return false }
            if out.contains("no match") || out.contains("incomplete") {
                return false
            }
            if !mac.isEmpty {
                let cleanMac = mac.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "-", with: "").lowercased()
                let cleanOut = out.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "-", with: "")
                return cleanOut.contains(cleanMac) || out.contains("(")
            }
            return out.contains("(") && out.contains("at ")
        } catch {
            return false
        }
    }

    // MARK: - Local UDP Command Sending

    /// Sends a JSON control command directly to the fan over local UDP port 5600
    func sendCommand(_ command: DeviceCommand, to device: SmartDevice) async throws {
        var host = device.ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if host.isEmpty || host.lowercased() == "cloud" {
            // Check if local discovery knows the IP
            if let cached = lastDiscoveredDevices.first(where: { $0.id == device.id || $0.localKey.lowercased() == device.localKey.lowercased() }) {
                host = cached.ipAddress
                device.ipAddress = host
            } else {
                throw NetworkError.protocolError("Device local IP is not configured. Please use Auto-Detect on Wi-Fi.")
            }
        }

        // Verify physical reachability before command
        let isReachable = await checkLocalReachability(ip: host, mac: device.localKey)
        if !isReachable {
            device.isOnline = false
            // Keep device.isOn untouched so power state is preserved
            device.triggerUnreachableAlert(reason: "Fan is unreachable. Wall switch is OFF or disconnected.")
            throw NetworkError.deviceUnreachable("Wall switch is OFF or fan is disconnected")
        }

        var dict: [String: Any] = [:]
        switch command {
        case .power(let on):
            if on {
                let speedToSend = max(1, min(6, device.speed == 0 ? 3 : device.speed))
                dict["power"] = true
                dict["speed"] = speedToSend
            } else {
                dict["power"] = false
            }

        case .fanSpeed(let speed):
            let clamped = max(1, min(6, speed))
            dict["power"] = true
            dict["speed"] = clamped

        case .fanBoost(let boost):
            if boost {
                dict["power"] = true
                dict["speed"] = 6
            } else {
                let regularSpeed = max(1, min(5, device.speed == 6 ? 3 : device.speed))
                dict["power"] = true
                dict["speed"] = regularSpeed
            }

        case .fanSleep(let sleep):
            dict["sleep"] = sleep

        case .fanTimer(let hours):
            dict["timer"] = hours

        case .fanLed(let led):
            dict["led"] = led

        default:
            return
        }

        let jsonData = try JSONSerialization.data(withJSONObject: dict)
        try await sendUDP(data: jsonData, to: host, port: commandPort)

        // Optimistically update device on MainActor
        device.isOnline = true
        device.lastSeen = Date()
        switch command {
        case .power(let on):
            device.isOn = on
            if on && device.speed == 0 { device.speed = 3 }
        case .fanSpeed(let speed):
            device.isOn = true
            device.speed = max(1, min(6, speed))
            device.isBoostMode = (speed == 6)
        case .fanBoost(let boost):
            device.isBoostMode = boost
            if boost {
                device.isOn = true
                device.speed = 6
            }
        case .fanSleep(let sleep):
            device.isSleepMode = sleep
        case .fanTimer(let hours):
            device.timerMinutes = hours * 60
        case .fanLed(let led):
            device.isLedOn = led
        default:
            break
        }
    }

    private func sendUDP(data: Data, to host: String, port: UInt16) async throws {
        let endpoint = NWEndpoint.hostPort(host: .init(host), port: .init(integerLiteral: port))
        let params = NWParameters.udp
        let connection = NWConnection(to: endpoint, using: params)

        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            let lock = NSLock()

            func resumeOnce(_ result: Result<Void, Error>) {
                lock.lock()
                defer { lock.unlock() }
                guard !hasResumed else { return }
                hasResumed = true
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let err):
                    continuation.resume(throwing: err)
                }
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: data, completion: .contentProcessed { error in
                        if let error = error {
                            resumeOnce(.failure(error))
                        } else {
                            resumeOnce(.success(()))
                        }
                        connection.cancel()
                    })
                case .failed(let error):
                    resumeOnce(.failure(error))
                default:
                    break
                }
            }

            connection.start(queue: .global())

            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                resumeOnce(.failure(NetworkError.timeout))
                connection.cancel()
            }
        }
    }

    // MARK: - Auto-Discovery via Socket Command

    /// Discovers Atomberg fans using the high-reliability UDP socket discovery command on port 5625
    func discover(timeout: TimeInterval = 3.0) async -> [SmartDevice] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
                let pyScript = "import socket; s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1); s.bind(('0.0.0.0',5625)); s.settimeout(\(timeout)); d,a=s.recvfrom(1024); print(f'{a[0]},{d.decode().strip()}'); s.close()"
                proc.arguments = ["-c", pyScript]
                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = Pipe()

                do {
                    try proc.run()
                    proc.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !output.isEmpty {
                        let parts = output.split(separator: ",")
                        if parts.count >= 2 {
                            let ip = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                            let mac = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

                            Task { @MainActor in
                                let dev = SmartDevice(
                                    id: "atomberg_\(mac)",
                                    name: "Atomberg Fan",
                                    brand: .atomberg,
                                    type: .fan,
                                    ipAddress: ip
                                )
                                dev.isOnline = true
                                dev.isOn = true
                                dev.localKey = mac.uppercased()
                                dev.lastSeen = Date()

                                self.lastDiscoveredDevices = [dev]
                                continuation.resume(returning: [dev])
                            }
                            return
                        }
                    }
                } catch {
                    print("Atomberg discovery command error: \(error)")
                }
                continuation.resume(returning: [])
            }
        }
    }
}
