import Foundation
import Network

actor UDPConnection {
    func send(data: Data, to host: String, port: UInt16) async throws {
        let endpoint = NWEndpoint.hostPort(host: .init(host), port: .init(integerLiteral: port))
        let connection = NWConnection(to: endpoint, using: .udp)

        return try await withCheckedThrowingContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: data, completion: .contentProcessed { error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                        connection.cancel()
                    })
                case .failed(let error):
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            connection.start(queue: .global())
        }
    }

    func sendAndReceive(data: Data, to host: String, port: UInt16, timeout: TimeInterval = 2.5) async throws -> Data {
        let endpoint = NWEndpoint.hostPort(host: .init(host), port: .init(integerLiteral: port))
        let connection = NWConnection(to: endpoint, using: .udp)

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            let lock = NSLock()

            func safeResume(_ block: () -> Void) {
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                block()
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: data, completion: .contentProcessed { error in
                        if let error = error {
                            safeResume { continuation.resume(throwing: error) }
                            connection.cancel()
                            return
                        }
                        connection.receiveMessage { content, _, _, recvError in
                            if let content = content {
                                safeResume { continuation.resume(returning: content) }
                            } else if let recvError = recvError {
                                safeResume { continuation.resume(throwing: recvError) }
                            } else {
                                safeResume { continuation.resume(throwing: NetworkError.noResponse) }
                            }
                            connection.cancel()
                        }
                    })
                case .failed(let error):
                    safeResume { continuation.resume(throwing: error) }
                default:
                    break
                }
            }
            connection.start(queue: .global())

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                safeResume { continuation.resume(throwing: NetworkError.timeout) }
                connection.cancel()
            }
        }
    }

    func broadcast(data: Data, port: UInt16, timeout: TimeInterval = 3.0) async throws -> [(Data, String)] {
        return try await withCheckedThrowingContinuation { continuation in
            var results: [(Data, String)] = []
            var resumed = false
            let lock = NSLock()

            let params = NWParameters.udp
            params.allowLocalEndpointReuse = true

            let endpoint = NWEndpoint.hostPort(host: .init("255.255.255.255"), port: .init(integerLiteral: port))
            let conn = NWConnection(to: endpoint, using: params)

            conn.stateUpdateHandler = { state in
                if case .ready = state {
                    conn.send(content: data, completion: .contentProcessed { _ in
                        func receiveNext() {
                            conn.receiveMessage { content, _, _, _ in
                                if let content = content {
                                    lock.lock()
                                    if !resumed {
                                        results.append((content, "discovered"))
                                    }
                                    lock.unlock()
                                    receiveNext()
                                }
                            }
                        }
                        receiveNext()
                    })
                }
            }
            conn.start(queue: .global())

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                lock.lock()
                guard !resumed else { lock.unlock(); return }
                resumed = true
                lock.unlock()
                conn.cancel()
                continuation.resume(returning: results)
            }
        }
    }
}
