import Foundation

struct TuyaProtocol {
    static let prefix: [UInt8] = [0x00, 0x00, 0x55, 0xAA]
    static let suffix: [UInt8] = [0x00, 0x00, 0xAA, 0x55]
    static let version33Header: [UInt8] = [0x33, 0x2E, 0x33, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]

    enum Command: UInt32 {
        case control = 7
        case status = 8
        case heartbeat = 9
        case dpQuery = 10
        case dpQueryNew = 16
    }

    static func buildMessage(command: Command, payload: [String: Any], sequenceNumber: UInt32 = 0, localKey: String) -> Data? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let keyData = localKey.data(using: .utf8), keyData.count == 16,
              let encrypted = TuyaCrypto.encrypt(jsonData, key: keyData) else { return nil }
        var payloadWithVersion = Data(version33Header)
        payloadWithVersion.append(encrypted)
        var frame = Data()
        frame.append(contentsOf: prefix)
        var seq = sequenceNumber.bigEndian
        frame.append(Data(bytes: &seq, count: 4))
        var cmd = command.rawValue.bigEndian
        frame.append(Data(bytes: &cmd, count: 4))
        var totalLength = UInt32(payloadWithVersion.count + 8).bigEndian
        frame.append(Data(bytes: &totalLength, count: 4))
        frame.append(payloadWithVersion)
        var crc = crc32(frame).bigEndian
        frame.append(Data(bytes: &crc, count: 4))
        frame.append(contentsOf: suffix)
        return frame
    }

    static func parseResponse(data: Data, localKey: String) -> [String: Any]? {
        guard data.count >= 20 else { return nil }
        let bytes = [UInt8](data)
        guard bytes[0...3].elementsEqual(prefix) else { return nil }
        let payloadLength = UInt32(bytes[12]) << 24 | UInt32(bytes[13]) << 16 | UInt32(bytes[14]) << 8 | UInt32(bytes[15])
        let payloadEnd = 16 + Int(payloadLength) - 8
        guard payloadEnd > 16, payloadEnd <= data.count else { return nil }
        var payload = Data(bytes[16..<payloadEnd])
        if payload.count > 15 {
            let versionCheck = [UInt8](payload[0..<3])
            if versionCheck == [0x33, 0x2E, 0x33] { payload = Data(payload[15...]) }
        }
        guard let keyData = localKey.data(using: .utf8),
              let decrypted = TuyaCrypto.decrypt(payload, key: keyData) else {
            return try? JSONSerialization.jsonObject(with: payload) as? [String: Any]
        }
        return try? JSONSerialization.jsonObject(with: decrypted) as? [String: Any]
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc & 1 == 1) ? (crc >> 1) ^ 0xEDB88320 : crc >> 1
            }
        }
        return crc ^ 0xFFFFFFFF
    }
}
