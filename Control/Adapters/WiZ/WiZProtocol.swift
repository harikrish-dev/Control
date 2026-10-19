import Foundation

struct WiZCommands {
    static func registration(ip: String, mac: String = "AAAAAAAAAAAA") -> Data {
        let msg: [String: Any] = [
            "method": "registration",
            "params": ["phoneMac": mac, "register": false, "phoneIp": ip]
        ]
        return (try? JSONSerialization.data(withJSONObject: msg)) ?? Data()
    }

    static func getPilot() -> Data {
        let msg: [String: Any] = ["method": "getPilot", "params": [String: String]()]
        return (try? JSONSerialization.data(withJSONObject: msg)) ?? Data()
    }

    static func getSystemConfig() -> Data {
        let msg: [String: Any] = ["method": "getSystemConfig", "params": [String: String]()]
        return (try? JSONSerialization.data(withJSONObject: msg)) ?? Data()
    }

    static func setPilot(on: Bool) -> Data {
        let msg: [String: Any] = ["method": "setPilot", "params": ["state": on]]
        return (try? JSONSerialization.data(withJSONObject: msg)) ?? Data()
    }

    static func setPilot(brightness: Int) -> Data {
        let dimming = max(10, min(100, brightness))
        let msg: [String: Any] = ["method": "setPilot", "params": ["state": true, "dimming": dimming]]
        return (try? JSONSerialization.data(withJSONObject: msg)) ?? Data()
    }

    static func setPilot(colorTemp: Int) -> Data {
        let temp = max(2200, min(6500, colorTemp))
        let msg: [String: Any] = ["method": "setPilot", "params": ["state": true, "temp": temp]]
        return (try? JSONSerialization.data(withJSONObject: msg)) ?? Data()
    }

    static func setPilot(r: Int, g: Int, b: Int, brightness: Int = 100) -> Data {
        let msg: [String: Any] = [
            "method": "setPilot",
            "params": ["state": true, "r": r, "g": g, "b": b, "dimming": brightness]
        ]
        return (try? JSONSerialization.data(withJSONObject: msg)) ?? Data()
    }

    static func setPilot(sceneId: Int) -> Data {
        let msg: [String: Any] = ["method": "setPilot", "params": ["state": true, "sceneId": sceneId]]
        return (try? JSONSerialization.data(withJSONObject: msg)) ?? Data()
    }
}

struct WiZScenes {
    static let scenes: [(id: Int, name: String, icon: String)] = [
        (1, "Ocean", "water.waves"),
        (2, "Romance", "heart.fill"),
        (3, "Sunset", "sunset.fill"),
        (4, "Party", "party.popper.fill"),
        (5, "Fireplace", "flame.fill"),
        (6, "Cozy", "cup.and.saucer.fill"),
        (7, "Forest", "leaf.fill"),
        (8, "Pastel", "paintpalette.fill"),
        (9, "Wake Up", "sunrise.fill"),
        (10, "Bedtime", "moon.fill"),
        (11, "Warm White", "lightbulb.fill"),
        (12, "Daylight", "sun.max.fill"),
        (13, "Cool White", "snowflake"),
        (14, "Night Light", "moon.stars.fill"),
        (15, "Focus", "eye.fill"),
        (16, "Relax", "figure.mind.and.body"),
        (18, "TV Time", "tv.fill"),
        (32, "Diwali", "sparkles")
    ]
}
