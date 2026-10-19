import Foundation
import Network

@MainActor
final class AtombergLocalAdapter {
    static let shared = AtombergLocalAdapter()

    private let commandPort: UInt16 = 5600
    private let beaconPort: UInt16 = 5625

    private(set) var lastDiscoveredDevices: [SmartDevice] = []

    private init() {}

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
