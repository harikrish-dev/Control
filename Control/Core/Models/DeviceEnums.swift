import Foundation
import SwiftUI

enum DeviceBrand: String, Codable, CaseIterable, Identifiable {
    case wiz = "WiZ"
    case homemate = "Homemate"
    case atomberg = "Atomberg"
    case carrier = "Carrier"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .wiz: return "lightbulb.fill"
        case .homemate: return "powerplug.fill"
        case .atomberg: return "fan.fill"
        case .carrier: return "snowflake"
        }
    }

    var color: Color {
        switch self {
        case .wiz: return .yellow
        case .homemate: return .green
        case .atomberg: return .blue
        case .carrier: return .cyan
        }
    }
}

enum DeviceType: String, Codable, CaseIterable {
    case light
    case plug
    case fan
    case airConditioner

    var icon: String {
        switch self {
        case .light: return "lightbulb.fill"
        case .plug: return "powerplug.fill"
        case .fan: return "fan.fill"
        case .airConditioner: return "snowflake"
        }
    }

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .plug: return "Smart Plug"
        case .fan: return "Fan"
        case .airConditioner: return "Air Conditioner"
        }
    }
}

enum ACMode: String, Codable, CaseIterable, Identifiable {
    case cool, heat, dry, fan, auto
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .cool: return "snowflake"
        case .heat: return "flame.fill"
        case .dry: return "drop.fill"
        case .fan: return "fan.fill"
        case .auto: return "arrow.triangle.2.circlepath"
        }
    }
    var displayName: String { rawValue.capitalized }
}

enum ACFanSpeed: String, Codable, CaseIterable, Identifiable {
    case auto, silent, low, medium, high
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum FlexicoolLevel: Int, Codable, CaseIterable, Identifiable {
    case full = 100
    case threeQuarter = 75
    case half = 50
    case quarter = 25
    var id: Int { rawValue }
    var displayName: String { "\(rawValue)%" }
}
