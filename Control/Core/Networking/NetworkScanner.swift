import Foundation
#if canImport(Darwin)
import Darwin
#endif

struct DiscoveredIP: Identifiable, Hashable {
    let id: String
    let ip: String
    let mac: String
    let suspectedDevice: String
    let brand: DeviceBrand?

    init(ip: String, mac: String = "", suspectedDevice: String, brand: DeviceBrand? = nil) {
        self.id = ip
        self.ip = ip
        self.mac = mac
        self.suspectedDevice = suspectedDevice
        self.brand = brand
    }
}

@MainActor
final class NetworkScanner {
    static let shared = NetworkScanner()

    func scanLocalNetwork() async -> [DiscoveredIP] {
        var results: [DiscoveredIP] = []

        // Run ARP table lookup from macOS
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/arp")
        process.arguments = ["-an"]
        process.standardOutput = pipe

        try? process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        for line in output.components(separatedBy: "\n") {
            // Sample line: ? (192.168.1.X) at aa:bb:cc:dd:ee:ff on en0 ifscope [ethernet]
            guard line.contains("(") && line.contains(")") && line.contains(" at ") else { continue }
            guard !line.contains("incomplete") && !line.contains("permanent") else { continue }

            guard let openParen = line.firstIndex(of: "("),
                  let closeParen = line.firstIndex(of: ")"),
                  openParen < closeParen else { continue }

            let rawIp = String(line[line.index(after: openParen)..<closeParen]).trimmingCharacters(in: .whitespaces)

            // Skip broadcast, multicast, loopback, and router/gateway heuristics
            guard !rawIp.hasPrefix("224.") && !rawIp.hasPrefix("239.") && !rawIp.hasPrefix("255.") && !rawIp.hasPrefix("127.") else { continue }
            guard !rawIp.hasSuffix(".255") else { continue }

            // Extract MAC address
            let afterAt = line.components(separatedBy: " at ")
            guard afterAt.count >= 2 else { continue }
            let macParts = afterAt[1].components(separatedBy: " ")
            guard !macParts.isEmpty else { continue }
            let rawMac = macParts[0].trimmingCharacters(in: .whitespaces).lowercased()

            guard rawMac != "ff:ff:ff:ff:ff:ff" && rawMac != "(incomplete)" else { continue }

            // Normalize MAC address format (e.g. 70:4:1d -> 70:04:1d)
            let formattedMac = rawMac.components(separatedBy: ":").map { part in
                part.count == 1 ? "0\(part)" : part
            }.joined(separator: ":")

            // Brand & Device identification via MAC OUI prefixes
            var detectedBrand: DeviceBrand? = nil
            var deviceName = "Network Device"

            if formattedMac.hasPrefix("d8:a0:11") {
                detectedBrand = .wiz
                deviceName = "WiZ Smart Light"
            } else if formattedMac.hasPrefix("70:04:1d") || formattedMac.hasPrefix("24:6f:28") ||
                        formattedMac.hasPrefix("30:ae:a4") || formattedMac.hasPrefix("84:f3:eb") ||
                        formattedMac.hasPrefix("68:b6:b3") || formattedMac.hasPrefix("bc:dd:c2") {
                detectedBrand = .homemate
                deviceName = "Homemate / Tuya Smart Device"
            } else if rawIp.hasSuffix(".1") {
                deviceName = "Local Gateway / Router"
            } else {
                deviceName = "Device (\(formattedMac))"
            }

            // Quick live UDP check for WiZ bulbs on port 38899
            if detectedBrand == nil && isWiZBulb(ip: rawIp) {
                detectedBrand = .wiz
                deviceName = "WiZ Smart Light"
            }

            results.append(DiscoveredIP(
                ip: rawIp,
                mac: formattedMac,
                suspectedDevice: deviceName,
                brand: detectedBrand
            ))
        }

        return results
    }

    private func isWiZBulb(ip: String) -> Bool {
        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else { return false }
        defer { close(sock) }

        var tv = timeval(tv_sec: 0, tv_usec: 200_000) // 200ms quick probe
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(38899).bigEndian
        inet_pton(AF_INET, ip, &addr.sin_addr)

        let msg = Data("{\"method\":\"getPilot\",\"params\":{}}".utf8)
        _ = msg.withUnsafeBytes { raw in
            withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    sendto(sock, raw.baseAddress, msg.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }

        var buf = [UInt8](repeating: 0, count: 512)
        let bytesRead = recv(sock, &buf, buf.count, 0)
        return bytesRead > 0
    }
}
