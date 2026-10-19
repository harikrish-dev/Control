import Foundation

struct MideaProtocol {
    static func buildControlCommand(power: Bool, temperature: Double, mode: ACMode,
                                     fanSpeed: ACFanSpeed, swing: Bool, turbo: Bool, eco: Bool) -> Data {
        var body = Data(repeating: 0, count: 25)
        body[0] = 0xAA; body[1] = 0x19; body[2] = 0xAC
        body[9] = 0x02; body[10] = 0x40
        var byte11: UInt8 = power ? 0x01 : 0x00
        byte11 |= modeToRaw(mode) << 5
        body[11] = byte11
        let tempInt = UInt8(max(16, min(30, temperature)))
        let tempHalf = (temperature - Double(tempInt)) >= 0.5
        body[12] = (tempInt & 0x0F) | (tempHalf ? 0x10 : 0x00)
        body[13] = fanSpeedToRaw(fanSpeed)
        body[15] = swing ? 0x0C : 0x00
        body[17] = turbo ? 0x20 : 0x00
        body[19] = eco ? 0x80 : 0x00
        body.append(checksum(body))
        return body
    }

    private static func modeToRaw(_ mode: ACMode) -> UInt8 {
        switch mode { case .auto: return 1; case .cool: return 2; case .dry: return 3; case .heat: return 4; case .fan: return 5 }
    }
    private static func fanSpeedToRaw(_ speed: ACFanSpeed) -> UInt8 {
        switch speed { case .auto: return 102; case .silent: return 20; case .low: return 40; case .medium: return 60; case .high: return 80 }
    }
    private static func checksum(_ data: Data) -> UInt8 {
        var sum: UInt8 = 0
        for i in 1..<data.count { sum = sum &+ data[i] }
        return 255 &- sum &+ 1
    }
}
