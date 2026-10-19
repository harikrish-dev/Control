import Foundation

@MainActor
final class AtombergCloudAdapter {
    static let shared = AtombergCloudAdapter()
    private let baseURL = "https://api.developer.atomberg-iot.com"

    private let kAtombergApiKey = "atomberg_api_key"
    private let kAtombergRefreshToken = "atomberg_refresh_token"

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: kAtombergApiKey) ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: kAtombergApiKey)
            UserDefaults.standard.synchronize()
        }
    }

    var refreshToken: String {
        get { UserDefaults.standard.string(forKey: kAtombergRefreshToken) ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: kAtombergRefreshToken)
            UserDefaults.standard.synchronize()
        }
    }

    private var accessToken: String? = nil
    private var tokenExpiry: Date? = nil

    private func cleanCredential(_ raw: String) -> String {
        var str = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("\"") && str.hasSuffix("\"") && str.count >= 2 {
            str = String(str.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if str.hasPrefix("'") && str.hasSuffix("'") && str.count >= 2 {
            str = String(str.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return str
    }

    func resolveDeviceId(for device: SmartDevice) -> String {
        let cleanLocal = device.localKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !cleanLocal.isEmpty && cleanLocal != "cloud" {
            return cleanLocal
        }
        let cleanId = device.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if cleanId.hasPrefix("atomberg_") {
            let suffix = String(cleanId.dropFirst("atomberg_".count))
            if !suffix.isEmpty { return suffix }
        }
        return cleanId
    }

    func getAccessToken() async throws -> String {
        if let token = accessToken, let expiry = tokenExpiry, expiry > Date() {
            return token
        }

        let key = cleanCredential(apiKey)
        var rawRefresh = cleanCredential(refreshToken)

        guard !key.isEmpty, !rawRefresh.isEmpty else {
            throw NetworkError.protocolError("Please provide both API Key and Refresh Token")
        }

        // Strip any redundant "Bearer " prefix if user copied it along with the token
        if rawRefresh.lowercased().hasPrefix("bearer ") {
            rawRefresh = String(rawRefresh.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let candidatePaths = ["/v1/get_access_token", "/v2/get-access-token", "/v2/get_access_token"]
        var lastError: Error = NetworkError.authenticationFailed

        for path in candidatePaths {
            guard let url = URL(string: "\(baseURL)\(path)") else { continue }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 9.0
            request.setValue(key, forHTTPHeaderField: "X-API-Key")
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("Bearer \(rawRefresh)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else { continue }

                if httpResponse.statusCode == 200 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let token = (json["message"] as? [String: Any])?["access_token"] as? String
                            ?? (json["data"] as? [String: Any])?["access_token"] as? String
                            ?? json["access_token"] as? String

                        if let validToken = token, !validToken.isEmpty {
                            self.accessToken = validToken
                            self.tokenExpiry = Date().addingTimeInterval(23 * 3600)
                            return validToken
                        }
                    }
                } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    var errorDetail = ""
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        errorDetail = (json["message"] as? String)
                            ?? (json["error"] as? String)
                            ?? (json["error_description"] as? String)
                            ?? ""
                    }
                    if errorDetail.isEmpty {
                        errorDetail = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                    }
                    lastError = NetworkError.protocolError("Authentication failed: \(errorDetail). Check API key & refresh token.")
                    if httpResponse.statusCode == 401 { break }
                } else {
                    let errorBody = String(data: data, encoding: .utf8) ?? ""
                    lastError = NetworkError.protocolError("Atomberg Cloud error (HTTP \(httpResponse.statusCode): \(errorBody))")
                }
            } catch {
                lastError = error
            }
        }

        throw lastError
    }

    func fetchDevices() async throws -> [SmartDevice] {
        let token = try await getAccessToken()
        let key = cleanCredential(apiKey)

        let candidatePaths = ["/v1/get_list_of_devices", "/v2/devices", "/v1/devices"]
        var smartDevices: [SmartDevice] = []
        var lastError: Error = NetworkError.noResponse

        for path in candidatePaths {
            guard let url = URL(string: "\(baseURL)\(path)") else { continue }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 9.0
            request.setValue(key, forHTTPHeaderField: "X-API-Key")
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else { continue }

                if httpResponse.statusCode == 200 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let items = (json["message"] as? [String: Any])?["devices_list"] as? [[String: Any]]
                            ?? (json["data"] as? [String: Any])?["devices_list"] as? [[String: Any]]
                            ?? (json["data"] as? [String: Any])?["devices"] as? [[String: Any]]
                            ?? json["devices_list"] as? [[String: Any]]
                            ?? json["devices"] as? [[String: Any]]
                            ?? []

                        for item in items {
                            let id = (item["device_id"] as? String) ?? (item["id"] as? String) ?? UUID().uuidString
                            let name = (item["name"] as? String) ?? (item["device_name"] as? String) ?? "Atomberg Fan"
                            let dev = SmartDevice(id: id, name: name, brand: .atomberg, type: .fan, ipAddress: "cloud")
                            dev.localKey = id.uppercased()
                            dev.isOnline = true
                            dev.speed = (item["last_recorded_speed"] as? Int) ?? (item["speed"] as? Int) ?? 3
                            dev.isOn = (item["power"] as? Bool) ?? true
                            smartDevices.append(dev)
                        }

                        if !smartDevices.isEmpty {
                            return smartDevices
                        } else {
                            throw NetworkError.protocolError("Connected successfully, but 0 fans found in your Atomberg account. Make sure your fan is added in the Atomberg app.")
                        }
                    }
                } else {
                    let errMsg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                    lastError = NetworkError.protocolError("Failed to fetch fan list (HTTP \(httpResponse.statusCode): \(errMsg))")
                }
            } catch {
                lastError = error
            }
        }

        if !smartDevices.isEmpty {
            return smartDevices
        }
        throw lastError
    }

    func sendCommand(_ command: DeviceCommand, to device: SmartDevice) async throws {
        let key = cleanCredential(apiKey)
        let devId = resolveDeviceId(for: device)

        if !key.isEmpty && !devId.isEmpty {
            do {
                let token = try await getAccessToken()
                guard let url = URL(string: "\(baseURL)/v1/send_command") else { return }

                var cmdDict: [String: Any] = [:]
                switch command {
                case .power(let on):
                    cmdDict["power"] = on
                case .fanSpeed(let speed):
                    cmdDict["power"] = true
                    cmdDict["speed"] = max(1, min(6, speed))
                case .fanBoost(let boost):
                    cmdDict["power"] = true
                    cmdDict["speed"] = boost ? 6 : 4
                case .fanSleep(let sleep):
                    cmdDict["sleep"] = sleep
                case .fanLed(let led):
                    cmdDict["led"] = led
                case .fanTimer(let minutes):
                    cmdDict["timer"] = minutes / 60
                default:
                    break
                }

                let body: [String: Any] = [
                    "device_id": devId,
                    "command": cmdDict
                ]

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(key, forHTTPHeaderField: "X-API-Key")
                request.setValue(key, forHTTPHeaderField: "x-api-key")
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)

                _ = try? await URLSession.shared.data(for: request)
            } catch {
                print("Atomberg send error: \(error)")
            }
        }

        // Update local state
        switch command {
        case .power(let on): device.isOn = on
        case .fanSpeed(let speed): device.speed = speed; device.isOn = true; device.isBoostMode = false
        case .fanBoost(let boost): device.isBoostMode = boost; if boost { device.speed = 6; device.isOn = true }
        case .fanSleep(let sleep): device.isSleepMode = sleep
        case .fanLed(let led): device.isLedOn = led
        case .fanTimer(let minutes): device.timerMinutes = minutes
        default: break
        }
    }

    func refreshState(_ device: SmartDevice) async {
        let key = cleanCredential(apiKey)
        guard !key.isEmpty else { return }

        let devId = resolveDeviceId(for: device)
        guard !devId.isEmpty else { return }

        do {
            let token = try await getAccessToken()
            guard var components = URLComponents(string: "\(baseURL)/v1/get_device_state") else { return }
            components.queryItems = [URLQueryItem(name: "device_id", value: devId)]
            guard let url = components.url else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(key, forHTTPHeaderField: "X-API-Key")
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 4.0

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let list = (json["message"] as? [String: Any])?["device_state"] as? [[String: Any]]
                    ?? (json["data"] as? [String: Any])?["device_state"] as? [[String: Any]]
                    ?? []

                if let state = list.first {
                    let isRecent = Date().timeIntervalSince(device.lastActionDate) < 4.0

                    if let online = state["is_online"] as? Bool {
                        device.isOnline = online
                    } else if let onlineInt = state["is_online"] as? Int {
                        device.isOnline = (onlineInt == 1)
                    } else {
                        device.isOnline = true
                    }

                    if !isRecent {
                        if let power = state["power"] as? Bool {
                            device.isOn = power
                        } else if let powerInt = state["power"] as? Int {
                            device.isOn = (powerInt == 1)
                        }

                        if let spd = state["last_recorded_speed"] as? Int ?? state["speed"] as? Int {
                            device.speed = spd
                            device.isBoostMode = (spd == 6)
                        }

                        if let sleep = state["sleep_mode"] as? Bool {
                            device.isSleepMode = sleep
                        } else if let sleepInt = state["sleep_mode"] as? Int {
                            device.isSleepMode = (sleepInt == 1)
                        }
                    }

                    if let led = state["led"] as? Bool {
                        device.isLedOn = led
                    } else if let ledInt = state["led"] as? Int {
                        device.isLedOn = (ledInt == 1)
                    }

                    if let timer = state["timer_hours"] as? Int {
                        device.timerMinutes = timer * 60
                    }
                    device.lastSeen = Date()
                }
            }
        } catch {
            print("Atomberg refreshState error: \(error)")
        }
    }
}
