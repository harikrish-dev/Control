import Foundation

enum NetworkError: Error, LocalizedError {
    case timeout
    case noResponse
    case connectionFailed
    case invalidData
    case encryptionError
    case authenticationFailed
    case deviceNotFound
    case protocolError(String)

    var errorDescription: String? {
        switch self {
        case .timeout: return "Connection timed out"
        case .noResponse: return "No response from device"
        case .connectionFailed: return "Connection failed"
        case .invalidData: return "Invalid data received"
        case .encryptionError: return "Encryption error"
        case .authenticationFailed: return "Authentication failed"
        case .deviceNotFound: return "Device not found"
        case .protocolError(let msg): return "Protocol error: \(msg)"
        }
    }
}
