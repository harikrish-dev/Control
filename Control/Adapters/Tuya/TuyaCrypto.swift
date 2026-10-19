import Foundation
import CommonCrypto

struct TuyaCrypto {
    static func encrypt(_ data: Data, key: Data) -> Data? {
        let keyBytes = [UInt8](key)
        let dataBytes = [UInt8](data)
        let bufferSize = dataBytes.count + kCCBlockSizeAES128
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        var numBytesEncrypted: size_t = 0
        let status = CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES128),
            CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode),
            keyBytes, kCCKeySizeAES128, nil,
            dataBytes, dataBytes.count, &buffer, bufferSize, &numBytesEncrypted)
        guard status == kCCSuccess else { return nil }
        return Data(buffer[..<numBytesEncrypted])
    }

    static func decrypt(_ data: Data, key: Data) -> Data? {
        let keyBytes = [UInt8](key)
        let dataBytes = [UInt8](data)
        let bufferSize = dataBytes.count + kCCBlockSizeAES128
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        var numBytesDecrypted: size_t = 0
        let status = CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES128),
            CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode),
            keyBytes, kCCKeySizeAES128, nil,
            dataBytes, dataBytes.count, &buffer, bufferSize, &numBytesDecrypted)
        guard status == kCCSuccess else { return nil }
        return Data(buffer[..<numBytesDecrypted])
    }

    static func md5(_ data: Data) -> Data {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { _ = CC_MD5($0.baseAddress, CC_LONG(data.count), &digest) }
        return Data(digest)
    }
}
