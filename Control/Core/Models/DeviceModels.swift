import Foundation
import SwiftUI

@MainActor
@Observable
class SmartDevice: Identifiable, Hashable {
    let id: String
    var name: String
    let brand: DeviceBrand
    let type: DeviceType
    var ipAddress: String
    var roomId: UUID?
    var isOnline: Bool = false
    var isOn: Bool = false
    var lastSeen: Date?
    var lastActionDate: Date = Date.distantPast
    var isFavorite: Bool = false

    // Unreachable / Offline Warning State
    var unreachableAlertMessage: String? = nil
    var unreachableTrigger: UUID? = nil
    private var alertResetTask: Task<Void, Never>? = nil

    // Light properties
    var brightness: Int = 100
    var colorTemperature: Int = 4000
    var red: Int = 255
    var green: Int = 255
    var blue: Int = 255
    var currentScene: String?

    // Fan properties
    var speed: Int = 3
    var isLedOn: Bool = true
    var isBoostMode: Bool = false
    var isSleepMode: Bool = false
    var timerMinutes: Int = 0

    // AC properties
    var targetTemperature: Double = 24.0
    var indoorTemperature: Double? = nil
    var outdoorTemperature: Double? = nil
    var acMode: ACMode = .cool
    var acFanSpeed: ACFanSpeed = .auto
    var isSwingOn: Bool = false
    var isTurbo: Bool = false
    var isEco: Bool = false
    var flexicoolLevel: FlexicoolLevel = .full

    // Plug properties
    var currentPower: Double? = nil
    var currentVoltage: Double? = nil
    var currentCurrent: Double? = nil

    // Multi-socket strip properties
    var isPowerStrip: Bool = false
    var socketCount: Int = 4
    var socketStates: [Bool] = [true, true, true, true]
    var socketNames: [String] = ["Socket 1", "Socket 2", "Socket 3", "Socket 4"]
    // Socket override protection against stale cloud polling (socketIndex: (state, timestamp))
    var pendingSocketOverrides: [Int: (state: Bool, timestamp: Date)] = [:]

    // Tuya-specific
    var localKey: String = ""
    var tuyaDeviceId: String = ""
    var protocolVersion: String = "3.3"

    // Midea-specific
    var mideaToken: String = ""
    var mideaKey: String = ""
    var mideaDeviceId: UInt64 = 0

    init(id: String, name: String, brand: DeviceBrand, type: DeviceType, ipAddress: String) {
        self.id = id
        self.name = name
        self.brand = brand
        self.type = type
        self.ipAddress = ipAddress
    }

    var unreachableTitle: String {
        switch type {
        case .light: return "Switch is OFF"
        case .fan: return "Fan Offline"
        case .plug: return "Strip Offline"
        case .airConditioner: return "AC Unreachable"
        }
    }

    var unreachableSubtitle: String {
        switch type {
        case .light: return "Turn on wall switch to power light"
        case .fan: return "Check wall switch or Wi-Fi"
        case .plug: return "Main power switch is off or disconnected"
        case .airConditioner: return "Unit powered off or no signal"
        }
    }

    var unreachableIcon: String {
        switch type {
        case .light: return "lightbulb.slash.fill"
        case .fan: return "fan.slash.fill"
        case .plug: return "powerplug.fill"
        case .airConditioner: return "snowflake.slash"
        }
    }

    var unreachableColor: Color {
        switch type {
        case .light: return Color(red: 1.0, green: 0.55, blue: 0.15) // Warm amber warning
        case .fan: return Color(red: 0.2, green: 0.75, blue: 0.95)   // Cyan warning
        case .plug: return Color(red: 0.95, green: 0.3, blue: 0.4)   // Red alert
        case .airConditioner: return Color(red: 0.3, green: 0.7, blue: 1.0)
        }
    }

    func triggerUnreachableAlert(reason: String? = nil) {
        self.isOnline = false
        self.isOn = false
        self.unreachableAlertMessage = reason ?? unreachableSubtitle
        self.unreachableTrigger = UUID()

        alertResetTask?.cancel()
        alertResetTask = Task {
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            if !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.35)) {
                    self.unreachableAlertMessage = nil
                }
            }
        }
    }

    func setSocketStateOptimistic(socketIndex: Int, isOn: Bool) {
        if socketIndex >= 1 && socketIndex <= socketStates.count {
            socketStates[socketIndex - 1] = isOn
            self.isOn = socketStates.contains(true)
            pendingSocketOverrides[socketIndex] = (isOn, Date())
            lastActionDate = Date()
        }
    }

    func setAllSocketsOptimistic(isOn: Bool) {
        self.isOn = isOn
        let now = Date()
        for i in 1...socketCount {
            if i <= socketStates.count {
                socketStates[i - 1] = isOn
                pendingSocketOverrides[i] = (isOn, now)
            }
        }
        lastActionDate = now
    }

    nonisolated static func == (lhs: SmartDevice, rhs: SmartDevice) -> Bool {
        lhs.id == rhs.id
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var color: Color {
        Color(red: Double(red) / 255.0, green: Double(green) / 255.0, blue: Double(blue) / 255.0)
    }

    var statusText: String {
        if !isOnline {
            switch type {
            case .light: return "Switch OFF"
            case .fan: return "Offline"
            case .plug: return "Offline"
            case .airConditioner: return "Unreachable"
            }
        }
        guard isOn else { return "Off" }
        switch type {
        case .light: return "\(brightness)%"
        case .fan: return isBoostMode ? "Boost" : "Speed \(speed)"
        case .airConditioner: return "\(Int(targetTemperature))°C · \(acMode.displayName)"
        case .plug:
            if isPowerStrip {
                let onCount = socketStates.filter { $0 }.count
                if let power = currentPower, power > 0 {
                    return "\(onCount)/\(socketCount) On · \(String(format: "%.1fW", power))"
                }
                return "\(onCount)/\(socketCount) On"
            }
            if let power = currentPower, power > 0 {
                return String(format: "%.1fW", power)
            }
            return "On"
        }
    }
}

// MARK: - Saved Device Persistence
struct SavedDevice: Codable {
    let id: String
    var name: String
    let brand: String
    let type: String
    var ipAddress: String
    var roomId: UUID?
    var isFavorite: Bool
    var isPowerStrip: Bool
    var socketCount: Int
    var socketStates: [Bool]
    var socketNames: [String]
    var tuyaDeviceId: String
    var localKey: String?
    var speed: Int
    var brightness: Int
    var colorTemperature: Int
    var red: Int
    var green: Int
    var blue: Int
    var targetTemperature: Double
    var currentPower: Double? = nil
    var currentVoltage: Double? = nil
    var currentCurrent: Double? = nil

    @MainActor init(from device: SmartDevice) {
        self.id = device.id
        self.name = device.name
        self.brand = device.brand.rawValue
        self.type = device.type.rawValue
        self.ipAddress = device.ipAddress
        self.roomId = device.roomId
        self.isFavorite = device.isFavorite
        self.isPowerStrip = device.isPowerStrip
        self.socketCount = device.socketCount
        self.socketStates = device.socketStates
        self.socketNames = device.socketNames
        self.tuyaDeviceId = device.tuyaDeviceId
        self.localKey = device.localKey
        self.speed = device.speed
        self.brightness = device.brightness
        self.colorTemperature = device.colorTemperature
        self.red = device.red
        self.green = device.green
        self.blue = device.blue
        self.targetTemperature = device.targetTemperature
        self.currentPower = device.currentPower
        self.currentVoltage = device.currentVoltage
        self.currentCurrent = device.currentCurrent
    }

    @MainActor func toSmartDevice() -> SmartDevice {
        let brandEnum = DeviceBrand(rawValue: brand) ?? .wiz
        let typeEnum = DeviceType(rawValue: type) ?? .plug
        let dev = SmartDevice(id: id, name: name, brand: brandEnum, type: typeEnum, ipAddress: ipAddress)
        dev.roomId = roomId
        dev.isFavorite = isFavorite
        dev.isPowerStrip = isPowerStrip
        dev.socketCount = socketCount
        dev.socketStates = socketStates
        dev.socketNames = socketNames
        dev.tuyaDeviceId = tuyaDeviceId
        dev.localKey = localKey ?? ""
        dev.speed = speed
        dev.brightness = brightness
        dev.colorTemperature = colorTemperature
        dev.red = red
        dev.green = green
        dev.blue = blue
        dev.targetTemperature = targetTemperature
        dev.currentPower = currentPower
        dev.currentVoltage = currentVoltage
        dev.currentCurrent = currentCurrent
        dev.isOnline = false
        return dev
    }
}
