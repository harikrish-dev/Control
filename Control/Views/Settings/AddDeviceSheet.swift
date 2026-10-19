import SwiftUI

struct AddDeviceSheet: View {
    @Bindable var manager: DeviceManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: DeviceBrand = .wiz
    @State private var deviceName: String = ""
    @State private var ipAddress: String = ""
    @State private var isScanning: Bool = false
    @State private var scanResult: String? = nil

    // Atomberg local & cloud
    @State private var isScanningAtomberg: Bool = false
    @State private var atombergScanResult: String? = nil
    @State private var atombergLocalIP: String = ""
    @State private var showCloudOptions: Bool = false
    @State private var copiedCommand: Bool = false
    @State private var atombergApiKey: String = ""
    @State private var atombergRefreshToken: String = ""
    @State private var atombergStatus: String? = nil
    @State private var isLinkingAtomberg: Bool = false

    // Homemate
    @State private var tuyaAccessId: String = TuyaCloudBridge.shared.accessId
    @State private var tuyaAccessSecret: String = TuyaCloudBridge.shared.accessSecret
    @State private var tuyaRegion: String = TuyaCloudBridge.shared.region
    @State private var tuyaDeviceId: String = ""
    @State private var tuyaStatus: String? = nil
    @State private var isConnectingTuya: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add New Device")
                        .font(.title2.bold())
                    Text("Connect your WiZ light, Atomberg fan, Carrier AC, or Homemate plug")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Brand Picker Tabs
            Picker("Brand", selection: $selectedTab) {
                ForEach(DeviceBrand.allCases) { brand in
                    Label(brand.rawValue, systemImage: brand.icon)
                        .tag(brand)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .wiz:
                        wizSection
                    case .atomberg:
                        atombergSection
                    case .carrier:
                        carrierSection
                    case .homemate:
                        homemateSection
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .frame(width: 520, height: 600)
    }

    // MARK: - WiZ Section
    private var wizSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Auto-Discovery (Recommended)", systemImage: "wifi")
                    .font(.headline)
                Text("Control broadcasts a discovery probe across your local Wi-Fi to automatically detect active WiZ lights.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Button(isScanning ? "Scanning..." : "Scan Local Wi-Fi") {
                        isScanning = true
                        Task {
                            let before = manager.devices.count
                            manager.discoverDevices()
                            try? await Task.sleep(nanoseconds: 1_200_000_000)
                            isScanning = false
                            let diff = manager.devices.count - before
                            if diff > 0 {
                                scanResult = "Discovered \(diff) WiZ light(s)!"
                            } else {
                                scanResult = "Scan complete. No new lights found."
                            }
                        }
                    }
                    .disabled(isScanning)

                    if let res = scanResult {
                        Text(res)
                            .font(.caption.bold())
                            .foregroundColor(.green)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.yellow.opacity(0.08))
            .cornerRadius(12)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Or Add by Manual IP")
                    .font(.headline)

                TextField("Device Name (e.g. Living Room Light)", text: $deviceName)
                    .textFieldStyle(.roundedBorder)
                TextField("IP Address (e.g. 192.168.1.50)", text: $ipAddress)
                    .textFieldStyle(.roundedBorder)

                Button("Save WiZ Device") {
                    guard !ipAddress.isEmpty else { return }
                    let name = deviceName.isEmpty ? "WiZ Light (\(ipAddress))" : deviceName
                    let dev = SmartDevice(id: "wiz_\(UUID().uuidString.prefix(6))", name: name, brand: .wiz, type: .light, ipAddress: ipAddress)
                    dev.isOnline = true
                    manager.addDevice(dev)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(ipAddress.isEmpty)
            }
        }
    }

    // MARK: - Atomberg Section
    private var atombergSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Method 1: Local Wi-Fi Auto-Discovery (Recommended)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "wifi.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                    Text("Local Wi-Fi Auto-Discovery (Recommended)")
                        .font(.headline)
                }

                Text("Connects directly to your Atomberg smart fan over local Wi-Fi (UDP). Operates with instant sub-50ms response, works offline, and has zero cloud rate limits.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Button(isScanningAtomberg ? "Scanning Wi-Fi..." : "Auto-Detect Fan on Wi-Fi") {
                        isScanningAtomberg = true
                        atombergScanResult = nil
                        Task {
                            let found = await AtombergLocalAdapter.shared.discover()
                            isScanningAtomberg = false
                            if let fan = found.first {
                                atombergScanResult = "Found \(fan.name) at \(fan.ipAddress) (MAC: \(fan.localKey))!"
                                atombergLocalIP = fan.ipAddress

                                // Link or update existing fan
                                if let existing = manager.devices.first(where: { $0.brand == .atomberg }) {
                                    existing.ipAddress = fan.ipAddress
                                    existing.localKey = fan.localKey
                                    existing.isOnline = true
                                    existing.lastSeen = Date()
                                } else {
                                    manager.addDevice(fan)
                                }
                                manager.saveDevices()

                                try? await Task.sleep(nanoseconds: 1_200_000_000)
                                dismiss()
                            } else {
                                atombergScanResult = "No fan beacon heard. Run the terminal command below to find the IP."
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(isScanningAtomberg)

                    if isScanningAtomberg {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }

                if let res = atombergScanResult {
                    HStack {
                        Image(systemName: res.contains("Found") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        Text(res)
                    }
                    .font(.caption.bold())
                    .foregroundColor(res.contains("Found") ? .green : .orange)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.08))
            .cornerRadius(12)

            // Manual Local IP Configuration with Terminal Hint
            VStack(alignment: .leading, spacing: 12) {
                Text("Or Add by Local IP Address")
                    .font(.headline)

                TextField("Fan Name (e.g. Flow / Living Room Fan)", text: $deviceName)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Local IP Address")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    TextField("Local IP Address (e.g. 192.168.1.50)", text: $atombergLocalIP)
                        .textFieldStyle(.roundedBorder)

                    // Terminal command hint box
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "terminal.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("Command to find fan IP:")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)

                            Spacer()

                            Button {
                                let cmd = "python3 -c \"import socket; s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.bind(('0.0.0.0',5625)); print('Fan IP:', s.recvfrom(1024)[1][0])\""
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(cmd, forType: .string)
                                copiedCommand = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    copiedCommand = false
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: copiedCommand ? "checkmark" : "doc.on.doc")
                                    Text(copiedCommand ? "Copied!" : "Copy Command")
                                }
                                .font(.caption2.bold())
                                .foregroundColor(copiedCommand ? .green : .blue)
                            }
                            .buttonStyle(.plain)
                        }

                        Text("python3 -c \"import socket; s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.bind(('0.0.0.0',5625)); print(s.recvfrom(1024)[1][0])\"")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.primary)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(6)
                            .textSelection(.enabled)
                    }
                    .padding(.top, 4)
                }

                Button("Save Local Fan") {
                    let name = deviceName.isEmpty ? "Atomberg Fan" : deviceName
                    let cleanIP = atombergLocalIP.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cleanIP.isEmpty else { return }

                    if let existing = manager.devices.first(where: { $0.brand == .atomberg }) {
                        existing.name = name
                        existing.ipAddress = cleanIP
                        existing.isOnline = true
                        existing.lastSeen = Date()
                    } else {
                        let dev = SmartDevice(
                            id: "atomberg_\(UUID().uuidString.prefix(6))",
                            name: name,
                            brand: .atomberg,
                            type: .fan,
                            ipAddress: cleanIP
                        )
                        dev.isOnline = true
                        dev.speed = 3
                        dev.isOn = true
                        manager.addDevice(dev)
                    }
                    manager.saveDevices()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(atombergLocalIP.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(12)

            // Method 2: Cloud API (Optional - strictly limited)
            DisclosureGroup(isExpanded: $showCloudOptions) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Atomberg Cloud API is strictly limited by Atomberg to 100 requests per day. For unlimited, instant control, use Local Wi-Fi above.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    TextField("x-api-key", text: $atombergApiKey)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Refresh Token", text: $atombergRefreshToken)
                        .textFieldStyle(.roundedBorder)

                    if let status = atombergStatus {
                        Text(status)
                            .font(.caption.bold())
                            .foregroundColor(status.contains("Success") ? .green : .red)
                    }

                    Button(isLinkingAtomberg ? "Connecting..." : "Link via Cloud API") {
                        isLinkingAtomberg = true
                        atombergStatus = nil
                        Task {
                            AtombergCloudAdapter.shared.apiKey = atombergApiKey
                            AtombergCloudAdapter.shared.refreshToken = atombergRefreshToken
                            do {
                                let fans = try await AtombergCloudAdapter.shared.fetchDevices()
                                for fan in fans {
                                    if !manager.devices.contains(where: { $0.id == fan.id }) {
                                        manager.devices.append(fan)
                                    }
                                }
                                isLinkingAtomberg = false
                                atombergStatus = "Success! Linked \(fans.count) fan(s)."
                                try? await Task.sleep(nanoseconds: 1_000_000_000)
                                dismiss()
                            } catch {
                                isLinkingAtomberg = false
                                atombergStatus = error.localizedDescription
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(atombergApiKey.isEmpty || atombergRefreshToken.isEmpty || isLinkingAtomberg)
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Image(systemName: "cloud.fill")
                        .foregroundColor(.secondary)
                    Text("Method 2: Atomberg Cloud API (Rate Limited)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.04))
            .cornerRadius(12)
        }
    }

    // MARK: - Carrier AC Section
    private var carrierSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Carrier Air Conditioner")
                .font(.headline)
            Text("Enter your Carrier AI Flexicool AC's local IP address:")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("Device Name (e.g. Master Bedroom AC)", text: $deviceName)
                .textFieldStyle(.roundedBorder)
            TextField("IP Address (e.g. 192.168.1.135)", text: $ipAddress)
                .textFieldStyle(.roundedBorder)

            Button("Save Carrier AC") {
                guard !ipAddress.isEmpty else { return }
                let name = deviceName.isEmpty ? "Carrier AC" : deviceName
                let dev = SmartDevice(id: "carrier_\(UUID().uuidString.prefix(6))", name: name, brand: .carrier, type: .airConditioner, ipAddress: ipAddress)
                dev.isOnline = true
                dev.targetTemperature = 24.0
                manager.addDevice(dev)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(ipAddress.isEmpty)
        }
        .padding()
        .background(Color.cyan.opacity(0.08))
        .cornerRadius(12)
    }

    // MARK: - Homemate Section
    private var homemateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "cloud.fill")
                        .foregroundColor(.green)
                    Text("Tuya / Homemate Cloud Bridge")
                        .font(.headline)
                }

                Text("Enter your Access ID and Secret from **iot.tuya.com** (Project Overview):")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.08))
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: 12) {
                // Access ID Field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Access ID / Client ID")
                        .font(.caption.bold())
                    TextField("Paste Access ID from Tuya project", text: $tuyaAccessId)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }

                // Access Secret Field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Access Secret")
                        .font(.caption.bold())
                    SecureField("Paste Access Secret from Tuya project", text: $tuyaAccessSecret)
                        .textFieldStyle(.roundedBorder)
                }

                // Data Center Picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Data Center / Region")
                        .font(.caption.bold())
                    Picker("Region", selection: $tuyaRegion) {
                        Text("🇮🇳 India Data Center (in)").tag("in")
                        Text("🇺🇸 Western America (us)").tag("us")
                        Text("🇪🇺 Central Europe (eu)").tag("eu")
                    }
                    .pickerStyle(.segmented)
                }

                // Device ID Field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Virtual ID / Device ID")
                        .font(.caption.bold())
                    TextField("Device ID", text: $tuyaDeviceId)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }

                if let status = tuyaStatus {
                    Text(status)
                        .font(.caption.bold())
                        .foregroundColor(status.contains("success") || status.contains("Connected") ? .green : .orange)
                        .lineLimit(2)
                }

                HStack {
                    Button(isConnectingTuya ? "Linking..." : "Link & Save 4-Socket Strip") {
                        isConnectingTuya = true
                        tuyaStatus = nil

                        Task {
                            TuyaCloudBridge.shared.accessId = tuyaAccessId
                            TuyaCloudBridge.shared.accessSecret = tuyaAccessSecret
                            TuyaCloudBridge.shared.region = tuyaRegion

                            let result = await TuyaCloudBridge.shared.testConnection(deviceId: tuyaDeviceId)
                            isConnectingTuya = false
                            tuyaStatus = result.message

                            // Save device into manager
                            let name = "Homemate 4-Socket Strip"
                            if let existing = manager.devices.first(where: { $0.brand == .homemate }) {
                                existing.tuyaDeviceId = tuyaDeviceId
                                existing.isPowerStrip = true
                                existing.socketCount = 4
                                existing.isOnline = true
                            } else {
                                let dev = SmartDevice(
                                    id: "homemate_\(tuyaDeviceId)",
                                    name: name,
                                    brand: .homemate,
                                    type: .plug,
                                    ipAddress: "cloud"
                                )
                                dev.tuyaDeviceId = tuyaDeviceId
                                dev.isPowerStrip = true
                                dev.socketCount = 4
                                dev.socketStates = [true, true, true, true]
                                dev.socketNames = ["Socket 1", "Socket 2", "Socket 3", "Socket 4"]
                                dev.isOnline = true
                                dev.isOn = true
                                manager.addDevice(dev)
                            }

                            if result.success {
                                try? await Task.sleep(nanoseconds: 800_000_000)
                                dismiss()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(tuyaAccessId.isEmpty || tuyaAccessSecret.isEmpty || isConnectingTuya)

                    Spacer()
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(12)
        }
    }
}
