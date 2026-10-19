struct TuyaDeviceTelemetry {
    var socketStates: [Int: Bool] = [:]
    var voltage: Double? = nil
    var power: Double? = nil
    var current: Double? = nil
}

import Foundation

@MainActor
final class TuyaCloudBridge {
    static let shared = TuyaCloudBridge()

    private let kAccessId = "tuya_access_id"
    private let kAccessSecret = "tuya_access_secret"
    private let kRegion = "tuya_region"

    var accessId: String {
        get { UserDefaults.standard.string(forKey: kAccessId) ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: kAccessId)
            UserDefaults.standard.synchronize()
        }
    }

    var accessSecret: String {
        get { UserDefaults.standard.string(forKey: kAccessSecret) ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: kAccessSecret)
            UserDefaults.standard.synchronize()
        }
    }

    var region: String {
        get { UserDefaults.standard.string(forKey: kRegion) ?? "in" }
        set {
            UserDefaults.standard.set(newValue, forKey: kRegion)
            UserDefaults.standard.synchronize()
        }
    }

    private var helperPath: String {
        // 1. App Bundle Resources
        if let bundlePath = Bundle.main.path(forResource: "tuya_helper", ofType: "py") {
            return bundlePath
        }
        let resURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/tuya_helper.py")
        if FileManager.default.fileExists(atPath: resURL.path) {
            return resURL.path
        }
        // 2. Working directory
        let localPath = FileManager.default.currentDirectoryPath + "/tuya_helper.py"
        if FileManager.default.fileExists(atPath: localPath) {
            return localPath
        }
        // 3. Application Support directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Control/tuya_helper.py").path
        return appSupport
    }

    func testConnection(deviceId: String) async -> (success: Bool, message: String) {
        guard !accessId.isEmpty, !accessSecret.isEmpty else {
            return (false, "Please enter your Access ID and Access Secret.")
        }

        let cleanKey = accessId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSecret = accessSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDevId = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        let reg = region
        let hPath = helperPath

        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
                process.arguments = [
                    hPath,
                    "test",
                    reg,
                    cleanKey,
                    cleanSecret,
                    cleanDevId
                ]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()

                do {
                    try process.run()
                    process.waitUntilExit()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""

                    DispatchQueue.main.async {
                        if output.contains("\"success\": true") {
                            continuation.resume(returning: (true, "Connected successfully to Tuya Cloud!"))
                        } else {
                            continuation.resume(returning: (false, output.isEmpty ? "Connection failed" : output))
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        continuation.resume(returning: (false, error.localizedDescription))
                    }
                }
            }
        }
    }

    func fetchDeviceTelemetry(deviceId: String) async -> TuyaDeviceTelemetry {
        guard !accessId.isEmpty, !accessSecret.isEmpty else { return TuyaDeviceTelemetry() }

        let cleanKey = accessId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSecret = accessSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDevId = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        let reg = region
        let hPath = helperPath

        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
                process.arguments = [
                    hPath,
                    "status",
                    reg,
                    cleanKey,
                    cleanSecret,
                    cleanDevId
                ]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()
                try? process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                var telemetry = TuyaDeviceTelemetry()

                guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                    DispatchQueue.main.async { continuation.resume(returning: telemetry) }
                    return
                }

                if let jsonStart = output.firstIndex(of: "{"),
                   let jsonData = output[jsonStart...].data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let items = json["result"] as? [[String: Any]] {
                    for item in items {
                        guard let code = item["code"] as? String else { continue }
                        let rawVal = item["value"]

                        // 1. Sockets on/off
                        let isValOn = (rawVal as? Bool) ?? ((rawVal as? Int) == 1)
                        if code.hasPrefix("switch_"), let num = Int(code.replacingOccurrences(of: "switch_", with: "")) {
                            telemetry.socketStates[num] = isValOn
                        } else if code.hasPrefix("switch"), let num = Int(code.replacingOccurrences(of: "switch", with: "")) {
                            telemetry.socketStates[num] = isValOn
                        } else if code == "switch" {
                            telemetry.socketStates[1] = isValOn
                        }

                        // 2. Voltage (cur_voltage in 0.1V, e.g. 2502 -> 250.2V)
                        if code == "cur_voltage" || code == "voltage" {
                            if let num = rawVal as? Double {
                                telemetry.voltage = num > 1000 ? (num / 10.0) : num
                            } else if let num = rawVal as? Int {
                                let d = Double(num)
                                telemetry.voltage = d > 1000 ? (d / 10.0) : d
                            }
                        }

                        // 3. Power / Total Load (cur_power in 0.1W, e.g. 479 -> 47.9W)
                        if code == "cur_power" || code == "power" {
                            if let num = rawVal as? Double {
                                telemetry.power = num / 10.0
                            } else if let num = rawVal as? Int {
                                telemetry.power = Double(num) / 10.0
                            }
                        }

                        // 4. Current (cur_current in mA, e.g. 278 -> 0.278A)
                        if code == "cur_current" || code == "current" {
                            if let num = rawVal as? Double {
                                telemetry.current = num / 1000.0
                            } else if let num = rawVal as? Int {
                                telemetry.current = Double(num) / 1000.0
                            }
                        }
                    }
                }

                DispatchQueue.main.async {
                    continuation.resume(returning: telemetry)
                }
            }
        }
    }

    func fetchStatus(deviceId: String) async -> [Int: Bool] {
        await fetchDeviceTelemetry(deviceId: deviceId).socketStates
    }

    func setSocketPower(deviceId: String, socketIndex: Int, isOn: Bool) async -> Bool {
        guard !accessId.isEmpty, !accessSecret.isEmpty else { return false }

        let cleanKey = accessId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSecret = accessSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDevId = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        let reg = region
        let hPath = helperPath

        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
                process.arguments = [
                    hPath,
                    "set",
                    reg,
                    cleanKey,
                    cleanSecret,
                    cleanDevId,
                    "\(socketIndex)",
                    isOn ? "true" : "false"
                ]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()
                try? process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let ok = process.terminationStatus == 0 && (output.contains("\"success\": true") || output.contains("true"))

                DispatchQueue.main.async {
                    continuation.resume(returning: ok)
                }
            }
        }
    }

    func setAllSocketsPower(deviceId: String, isOn: Bool) async -> Bool {
        guard !accessId.isEmpty, !accessSecret.isEmpty else { return false }

        let cleanKey = accessId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSecret = accessSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDevId = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        let reg = region
        let hPath = helperPath

        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
                process.arguments = [
                    hPath,
                    "set_all",
                    reg,
                    cleanKey,
                    cleanSecret,
                    cleanDevId,
                    isOn ? "true" : "false"
                ]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()
                try? process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let ok = process.terminationStatus == 0 && (output.contains("\"success\": true") || output.contains("true"))

                DispatchQueue.main.async {
                    continuation.resume(returning: ok)
                }
            }
        }
    }
}
