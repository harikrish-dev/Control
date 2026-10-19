import Foundation
import Network

actor TCPConnection {
    private var connection: NWConnection?
    private let host: String
    private let port: UInt16

    init(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }

    func connect() async throws {
        let endpoint = NWEndpoint.hostPort(host: .init(host), port: .init(integerLiteral: port))
        let tcp = NWProtocolTCP.Options()
        tcp.connectionTimeout = 5
        let params = NWParameters(tls: nil, tcp: tcp)
        let conn = NWConnection(to: endpoint, using: params)
        self.connection = conn

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var resumed = false
            conn.stateUpdateHandler = { state in
                guard !resumed else { return }
                switch state {
                case .ready:
                    resumed = true
                    continuation.resume()
                case .failed(let error):
                    resumed = true
                    continuation.resume(throwing: error)
                case .cancelled:
                    resumed = true
                    continuation.resume(throwing: NetworkError.connectionFailed)
                default:
                    break
                }
            }
            conn.start(queue: .global())
        }
    }

    func send(_ data: Data) async throws {
        guard let connection = connection else { throw NetworkError.connectionFailed }
        return try await withCheckedThrowingContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    func receive(length: Int = 4096) async throws -> Data {
        guard let connection = connection else { throw NetworkError.connectionFailed }
        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            connection.receive(minimumIncompleteLength: 1, maximumLength: length) { content, _, _, error in
                guard !resumed else { return }
                resumed = true
                if let content = content {
                    continuation.resume(returning: content)
                } else if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: NetworkError.noResponse)
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 4.0) {
                guard !resumed else { return }
                resumed = true
                continuation.resume(throwing: NetworkError.timeout)
            }
        }
    }

    func sendAndReceive(_ data: Data) async throws -> Data {
        try await send(data)
        return try await receive()
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
    }
}
