import Foundation
import CommonCrypto

struct MideaCrypto {
    static func aesEncryptECB(_ data: Data, key: Data) -> Data? {
        let keyBytes = [UInt8](key)
        let dataBytes = [UInt8](data)
        let bufferSize = dataBytes.count + kCCBlockSizeAES128
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        var numBytesEncrypted: size_t = 0
        let status = CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES128),
            CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode),
            keyBytes, min(keyBytes.count, kCCKeySizeAES256), nil,
            dataBytes, dataBytes.count, &buffer, bufferSize, &numBytesEncrypted)
        guard status == kCCSuccess else { return nil }
        return Data(buffer[..<numBytesEncrypted])
    }

    static func aesDecryptECB(_ data: Data, key: Data) -> Data? {
        let keyBytes = [UInt8](key)
        let dataBytes = [UInt8](data)
        let bufferSize = dataBytes.count + kCCBlockSizeAES128
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        var numBytesDecrypted: size_t = 0
        let status = CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES128),
            CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode),
            keyBytes, min(keyBytes.count, kCCKeySizeAES256), nil,
            dataBytes, dataBytes.count, &buffer, bufferSize, &numBytesDecrypted)
        guard status == kCCSuccess else { return nil }
        return Data(buffer[..<numBytesDecrypted])
    }
}
