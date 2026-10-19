import Foundation
import SwiftUI

struct SmartScene: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var subtitle: String
    var icon: String
    var accentColorName: String
    var commands: [SceneDeviceCommand]
    var isCustom: Bool

    init(
        id: UUID = UUID(),
        name: String,
        subtitle: String,
        icon: String,
        accentColorName: String = "blue",
        commands: [SceneDeviceCommand] = [],
        isCustom: Bool = false
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.icon = icon
        self.accentColorName = accentColorName
        self.commands = commands
        self.isCustom = isCustom
    }

    var accentColor: Color {
        switch accentColorName.lowercased() {
        case "indigo": return .indigo
        case "purple": return .purple
        case "red": return Color(red: 1.0, green: 0.35, blue: 0.35)
        case "blue": return .blue
        case "orange": return .orange
        case "green": return .green
        case "yellow": return .yellow
        case "cyan": return .cyan
        case "pink": return .pink
        case "mint": return .mint
        case "teal": return .teal
        default: return .cyan
        }
    }
}

struct SceneDeviceCommand: Hashable, Codable {
    var deviceId: String
    var command: DeviceCommand
}
