import Foundation
import SwiftUI

@MainActor
@Observable
final class DeviceManager {
    static let shared = DeviceManager()

    var devices: [SmartDevice] = []
    var rooms: [Room] = []
    var scenes: [SmartScene] = []
    var isDiscovering: Bool = false
    var isRefreshing: Bool = false
    var selectedDevice: SmartDevice? = nil
    var lastActivatedSceneId: UUID? = nil

    private let wizAdapter = WiZAdapter()
    private let tuyaAdapter = TuyaAdapter()
    private let mideaAdapter = MideaAdapter()

    private let storageDir: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("Control", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private var devicesFileURL: URL {
        storageDir.appendingPathComponent("devices.json")
    }

    private var scenesFileURL: URL {
        storageDir.appendingPathComponent("scenes.json")
    }

    init() {
        setupInitialRoomsAndScenes()
        if !loadDevices() {
            setupInitialDevices()
            saveDevices()
        }
        startLiveStatusPolling()
    }

    func saveDevices() {
        let saved = devices.map { SavedDevice(from: $0) }
        do {
            let data = try JSONEncoder().encode(saved)
            try data.write(to: devicesFileURL, options: .atomic)
            UserDefaults.standard.set(data, forKey: "saved_devices_backup")
            UserDefaults.standard.synchronize()
        } catch {
            print("Failed to save devices to disk: \(error)")
        }
    }

    private func loadDevices() -> Bool {
        if let data = try? Data(contentsOf: devicesFileURL),
           let saved = try? JSONDecoder().decode([SavedDevice].self, from: data),
           !saved.isEmpty {
            self.devices = saved.map { $0.toSmartDevice() }
            return true
        }

        if let data = UserDefaults.standard.data(forKey: "saved_devices_backup"),
           let saved = try? JSONDecoder().decode([SavedDevice].self, from: data),
           !saved.isEmpty {
            self.devices = saved.map { $0.toSmartDevice() }
            return true
        }

        return false
    }

    func saveScenes() {
        do {
            let data = try JSONEncoder().encode(scenes)
            try data.write(to: scenesFileURL, options: .atomic)
            UserDefaults.standard.set(data, forKey: "saved_scenes_backup")
            UserDefaults.standard.synchronize()
        } catch {
            print("Failed to save scenes to disk: \(error)")
        }
    }

    private func loadScenes() -> Bool {
        if let data = try? Data(contentsOf: scenesFileURL),
           let saved = try? JSONDecoder().decode([SmartScene].self, from: data),
           !saved.isEmpty {
            self.scenes = saved
            return true
        }

        if let data = UserDefaults.standard.data(forKey: "saved_scenes_backup"),
           let saved = try? JSONDecoder().decode([SmartScene].self, from: data),
           !saved.isEmpty {
            self.scenes = saved
            return true
        }

        return false
    }

    private func setupInitialRoomsAndScenes() {
        let livingRoom = Room(name: "Living Room", icon: "sofa.fill")
        let bedroom = Room(name: "Master Bedroom", icon: "bed.double.fill")
        let study = Room(name: "Study", icon: "books.vertical.fill")
        rooms = [livingRoom, bedroom, study]

        if !loadScenes() {
            setupInitialScenes()
            saveScenes()
        }
    }

    private func setupInitialScenes() {
        scenes = [
            SmartScene(
                name: "Good Night",
                subtitle: "Turn lights off, fan to silent",
                icon: "moon.stars.fill",
                accentColorName: "indigo",
                commands: []
            ),
            SmartScene(
                name: "Movie Mode",
                subtitle: "Warm dim lighting, quiet fan",
                icon: "film.fill",
                accentColorName: "purple",
                commands: []
            ),
            SmartScene(
                name: "Focus",
                subtitle: "Daylight brightness, cool focus",
                icon: "briefcase.fill",
                accentColorName: "blue",
                commands: []
            ),
            SmartScene(
                name: "Relax",
                subtitle: "Warm ambient glow, gentle breeze",
                icon: "cup.and.saucer.fill",
                accentColorName: "orange",
                commands: []
            ),
            SmartScene(
                name: "All Off",
                subtitle: "Switch off all connected appliances",
                icon: "power",
                accentColorName: "red",
                commands: []
            )
        ]
    }

    private func setupInitialDevices() {
        // First launch on a fresh installation: starts empty so user can scan their own Wi-Fi / add their own keys
        devices = []
    }

    func sendCommand(_ command: DeviceCommand, to device: SmartDevice) {
        device.lastActionDate = Date()
        Task {
            switch device.brand {
            case .wiz:
                try? await wizAdapter.sendCommand(command, to: device)
            case .atomberg:
                let hasLocalIP = !device.ipAddress.isEmpty && device.ipAddress.lowercased() != "cloud"
                if hasLocalIP {
                    do {
                        try await AtombergLocalAdapter.shared.sendCommand(command, to: device)
                    } catch {
                        if !AtombergCloudAdapter.shared.apiKey.isEmpty {
                            try? await AtombergCloudAdapter.shared.sendCommand(command, to: device)
                        }
                    }
                } else if !AtombergCloudAdapter.shared.apiKey.isEmpty {
                    try? await AtombergCloudAdapter.shared.sendCommand(command, to: device)
                } else {
                    // Try local discovery fallback
                    try? await AtombergLocalAdapter.shared.sendCommand(command, to: device)
                }
            case .homemate:
                try? await tuyaAdapter.sendCommand(command, to: device)
            case .carrier:
                try? await mideaAdapter.sendCommand(command, to: device)
            }
        }
    }

    func toggleDevice(_ device: SmartDevice) {
        device.lastActionDate = Date()
        sendCommand(.power(!device.isOn), to: device)
    }

    func activateScene(_ scene: SmartScene) {
        lastActivatedSceneId = scene.id

        Task {
            // Reset indicator after 2s
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if self.lastActivatedSceneId == scene.id {
                self.lastActivatedSceneId = nil
            }
        }

        Task {
            // 1. Explicit commands configured for this scene
            if !scene.commands.isEmpty {
                for action in scene.commands {
                    if let dev = self.devices.first(where: { $0.id == action.deviceId }) {
                        self.sendCommand(action.command, to: dev)
                        try? await Task.sleep(nanoseconds: 50_000_000)
                    }
                }
                return
            }

            // 2. Intelligent dynamic execution across active devices
            let lower = scene.name.lowercased()

            if lower.contains("all off") || lower.contains("turn off") || scene.icon == "power" {
                for dev in self.devices {
                    self.sendCommand(.power(false), to: dev)
                    try? await Task.sleep(nanoseconds: 40_000_000)
                }
            } else if lower.contains("good night") || lower.contains("night") || lower.contains("sleep") || scene.icon.contains("moon") {
                for dev in self.devices {
                    switch dev.type {
                    case .light:
                        self.sendCommand(.power(false), to: dev)
                    case .fan:
                        self.sendCommand(.fanSpeed(1), to: dev)
                        try? await Task.sleep(nanoseconds: 60_000_000)
                        self.sendCommand(.fanSleep(true), to: dev)
                    case .plug:
                        self.sendCommand(.power(false), to: dev)
                    case .airConditioner:
                        self.sendCommand(.power(true), to: dev)
                        try? await Task.sleep(nanoseconds: 60_000_000)
                        self.sendCommand(.acTemperature(24.0), to: dev)
                        try? await Task.sleep(nanoseconds: 60_000_000)
                        self.sendCommand(.acEco(true), to: dev)
                    }
                    try? await Task.sleep(nanoseconds: 40_000_000)
                }
            } else if lower.contains("movie") || lower.contains("cinema") || scene.icon.contains("film") {
                for dev in self.devices {
                    switch dev.type {
                    case .light:
                        if dev.brand == .wiz {
                            self.sendCommand(.scene("Cozy"), to: dev)
                            try? await Task.sleep(nanoseconds: 60_000_000)
                            self.sendCommand(.brightness(15), to: dev)
                        } else {
                            self.sendCommand(.power(true), to: dev)
                            try? await Task.sleep(nanoseconds: 60_000_000)
                            self.sendCommand(.brightness(15), to: dev)
                            try? await Task.sleep(nanoseconds: 60_000_000)
                            self.sendCommand(.colorTemperature(2200), to: dev)
                        }
                    case .fan:
                        self.sendCommand(.fanSpeed(2), to: dev)
                    case .airConditioner:
                        self.sendCommand(.power(true), to: dev)
                        try? await Task.sleep(nanoseconds: 60_000_000)
                        self.sendCommand(.acTemperature(24.0), to: dev)
                    case .plug:
                        break // Keep entertainment / media power on
                    }
                    try? await Task.sleep(nanoseconds: 40_000_000)
                }
            } else if lower.contains("focus") || lower.contains("work") || lower.contains("study") {
                for dev in self.devices {
                    switch dev.type {
                    case .light:
                        if dev.brand == .wiz {
                            self.sendCommand(.scene("Daylight"), to: dev)
                            try? await Task.sleep(nanoseconds: 60_000_000)
                            self.sendCommand(.brightness(100), to: dev)
                        } else {
                            self.sendCommand(.power(true), to: dev)
                            try? await Task.sleep(nanoseconds: 60_000_000)
                            self.sendCommand(.brightness(100), to: dev)
                            try? await Task.sleep(nanoseconds: 60_000_000)
                            self.sendCommand(.colorTemperature(5000), to: dev)
                        }
                    case .fan:
                        self.sendCommand(.fanSpeed(3), to: dev)
                    case .plug:
                        self.sendCommand(.power(true), to: dev)
                    case .airConditioner:
                        self.sendCommand(.power(true), to: dev)
                        try? await Task.sleep(nanoseconds: 60_000_000)
                        self.sendCommand(.acTemperature(23.0), to: dev)
                    }
                    try? await Task.sleep(nanoseconds: 40_000_000)
                }
            } else if lower.contains("relax") || lower.contains("cozy") || lower.contains("ambient") {
                for dev in self.devices {
                    switch dev.type {
                    case .light:
                        if dev.brand == .wiz {
                            self.sendCommand(.scene("Warm White"), to: dev)
                            try? await Task.sleep(nanoseconds: 60_000_000)
                            self.sendCommand(.brightness(40), to: dev)
                        } else {
                            self.sendCommand(.power(true), to: dev)
                            try? await Task.sleep(nanoseconds: 60_000_000)
                            self.sendCommand(.brightness(40), to: dev)
                            try? await Task.sleep(nanoseconds: 60_000_000)
                            self.sendCommand(.colorTemperature(2700), to: dev)
                        }
                    case .fan:
                        self.sendCommand(.fanSpeed(2), to: dev)
                    case .airConditioner:
                        self.sendCommand(.power(true), to: dev)
                        try? await Task.sleep(nanoseconds: 60_000_000)
                        self.sendCommand(.acTemperature(24.0), to: dev)
                    case .plug:
                        break
                    }
                    try? await Task.sleep(nanoseconds: 40_000_000)
                }
            } else if lower.contains("all on") || scene.icon.contains("sun.max") {
                for dev in self.devices {
                    self.sendCommand(.power(true), to: dev)
                    if dev.type == .light {
                        self.sendCommand(.brightness(100), to: dev)
                    } else if dev.type == .fan {
                        self.sendCommand(.fanSpeed(3), to: dev)
                    }
                    try? await Task.sleep(nanoseconds: 40_000_000)
                }
            }
        }
    }

    func addScene(_ scene: SmartScene) {
        scenes.append(scene)
        saveScenes()
    }

    func updateScene(_ scene: SmartScene) {
        if let idx = scenes.firstIndex(where: { $0.id == scene.id }) {
            scenes[idx] = scene
            saveScenes()
        }
    }

    func deleteScene(_ scene: SmartScene) {
        scenes.removeAll { $0.id == scene.id }
        saveScenes()
    }

    func removeDevice(_ device: SmartDevice) {
        devices.removeAll { $0.id == device.id }
        if selectedDevice?.id == device.id {
            selectedDevice = nil
        }
        saveDevices()
    }

    func addDevice(_ device: SmartDevice) {
        if !devices.contains(where: { $0.id == device.id }) {
            devices.append(device)
            saveDevices()
        }
    }

    func discoverDevices() {
        guard !isDiscovering else { return }
        isDiscovering = true
        Task {
            // WiZ Light Discovery
            let foundWiZ = await wizAdapter.discover()
            for dev in foundWiZ {
                if !devices.contains(where: { $0.id == dev.id }) {
                    devices.append(dev)
                }
            }

            // Atomberg Fan Discovery via command
            let foundFans = await AtombergLocalAdapter.shared.discover()
            for fan in foundFans {
                // If user previously had a fan with "cloud" ip or matching MAC, update its IP address
                if let existing = devices.first(where: { $0.brand == .atomberg && ($0.ipAddress == "cloud" || $0.localKey.lowercased() == fan.localKey.lowercased() || $0.ipAddress.isEmpty) }) {
                    existing.ipAddress = fan.ipAddress
                    existing.localKey = fan.localKey
                    existing.isOnline = true
                    existing.lastSeen = Date()
                } else if !devices.contains(where: { $0.id == fan.id }) {
                    devices.append(fan)
                }
            }

            saveDevices()
            isDiscovering = false
        }
    }

    func refreshAllDevices() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer {
            isRefreshing = false
            saveDevices()
        }

        // 1. Homemate 4-Socket Strip (Tuya Cloud)
        await syncTuyaDevices()

        // 2. WiZ Smart Light (Local UDP 38899)
        for device in devices where device.brand == .wiz {
            await wizAdapter.refreshState(device)
        }

        // 3. Atomberg Fan
        for device in devices where device.brand == .atomberg {
            if !AtombergCloudAdapter.shared.apiKey.isEmpty {
                await AtombergCloudAdapter.shared.refreshState(device)
            } else if !device.ipAddress.isEmpty && device.ipAddress != "cloud" {
                device.isOnline = true
            }
        }
    }

    private func startLiveStatusPolling() {
        Task {
            await refreshAllDevices()

            var pollCount = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                pollCount += 1

                // 1. Homemate 4-Socket Strip (every 2.5s)
                await syncTuyaDevices()

                // 2. WiZ Smart Light local UDP (every 2.5s)
                for device in devices where device.brand == .wiz {
                    await wizAdapter.refreshState(device)
                }

                // 3. Atomberg Fan: Cloud API is only polled every 60s if user has a cloud-only fan with valid API key.
                if pollCount % 24 == 0 {
                    for device in devices where device.brand == .atomberg && !AtombergCloudAdapter.shared.apiKey.isEmpty {
                        await AtombergCloudAdapter.shared.refreshState(device)
                    }
                }
            }
        }
    }

    private func syncTuyaDevices() async {
        for device in devices where device.brand == .homemate {
            guard !device.tuyaDeviceId.isEmpty else { continue }
            let telemetry = await TuyaCloudBridge.shared.fetchDeviceTelemetry(deviceId: device.tuyaDeviceId)
            let states = telemetry.socketStates
            guard !states.isEmpty || telemetry.voltage != nil || telemetry.power != nil else { continue }

            let now = Date()
            for (socketIdx, isOn) in states {
                if socketIdx >= 1 && socketIdx <= device.socketStates.count {
                    if let pending = device.pendingSocketOverrides[socketIdx] {
                        if now.timeIntervalSince(pending.timestamp) < 5.0 {
                            if isOn == pending.state {
                                device.pendingSocketOverrides.removeValue(forKey: socketIdx)
                                device.socketStates[socketIdx - 1] = isOn
                            } else {
                                device.socketStates[socketIdx - 1] = pending.state
                            }
                            continue
                        } else {
                            device.pendingSocketOverrides.removeValue(forKey: socketIdx)
                        }
                    }
                    device.socketStates[socketIdx - 1] = isOn
                }
            }
            if !states.isEmpty {
                device.isOn = device.socketStates.contains(true)
            }
            if let v = telemetry.voltage {
                device.currentVoltage = v
            }
            if let p = telemetry.power {
                device.currentPower = p
            }
            if let c = telemetry.current {
                device.currentCurrent = c
            }
            device.isOnline = true
            device.lastSeen = Date()
        }
    }
}
