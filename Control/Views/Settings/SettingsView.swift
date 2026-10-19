import SwiftUI

struct SettingsView: View {
    @Bindable var manager: DeviceManager
    @State private var tuyaAccessId: String = TuyaCloudBridge.shared.accessId
    @State private var tuyaAccessSecret: String = TuyaCloudBridge.shared.accessSecret
    @State private var tuyaRegion: String = TuyaCloudBridge.shared.region
    @State private var tuyaStatus: String? = nil
    @State private var isTesting: Bool = false
    @State private var isSaved: Bool = false
    @State private var tuyaTestDeviceId: String = ""

    @State private var atombergApiKey: String = AtombergCloudAdapter.shared.apiKey
    @State private var atombergRefreshToken: String = AtombergCloudAdapter.shared.refreshToken
    @State private var atombergStatus: String? = nil
    @State private var isTestingAtomberg: Bool = false
    @State private var isAtombergSaved: Bool = false

    var body: some View {
        Form {
            Section("Homemate / Tuya Cloud Bridge (Bi-directional Sync)") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Configure credentials from iot.tuya.com (Cloud -> Development -> Overview) to enable live status updates from your phone app:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Access ID / Client ID")
                            .font(.caption.bold())
                        TextField("Enter Tuya Access ID", text: $tuyaAccessId)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Access Secret")
                            .font(.caption.bold())
                        SecureField("Enter Tuya Access Secret", text: $tuyaAccessSecret)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Data Center Region")
                            .font(.caption.bold())
                        Picker("Region", selection: $tuyaRegion) {
                            Text("🇮🇳 India (in)").tag("in")
                            Text("🇺🇸 Western America (us)").tag("us")
                            Text("🇪🇺 Central Europe (eu)").tag("eu")
                        }
                        .pickerStyle(.segmented)
                    }

                    if let status = tuyaStatus {
                        Text(status)
                            .font(.caption.bold())
                            .foregroundColor(status.contains("success") || status.contains("Connected") ? .green : .orange)
                    }

                    HStack(spacing: 12) {
                        Button(action: {
                            TuyaCloudBridge.shared.accessId = tuyaAccessId.trimmingCharacters(in: .whitespacesAndNewlines)
                            TuyaCloudBridge.shared.accessSecret = tuyaAccessSecret.trimmingCharacters(in: .whitespacesAndNewlines)
                            TuyaCloudBridge.shared.region = tuyaRegion
                            isSaved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                isSaved = false
                            }
                        }) {
                            Label(isSaved ? "Saved!" : "Save Credentials", systemImage: isSaved ? "checkmark.circle.fill" : "square.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)

                        Button(action: {
                            isTesting = true
                            tuyaStatus = nil
                            TuyaCloudBridge.shared.accessId = tuyaAccessId.trimmingCharacters(in: .whitespacesAndNewlines)
                            TuyaCloudBridge.shared.accessSecret = tuyaAccessSecret.trimmingCharacters(in: .whitespacesAndNewlines)
                            TuyaCloudBridge.shared.region = tuyaRegion

                            let targetId = tuyaTestDeviceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? (manager.devices.first(where: { $0.brand == .homemate && !$0.tuyaDeviceId.isEmpty })?.tuyaDeviceId ?? "")
                                : tuyaTestDeviceId.trimmingCharacters(in: .whitespacesAndNewlines)

                            Task {
                                if targetId.isEmpty {
                                    isTesting = false
                                    tuyaStatus = "Please enter or select a Device ID to test."
                                    return
                                }
                                let res = await TuyaCloudBridge.shared.testConnection(deviceId: targetId)
                                isTesting = false
                                tuyaStatus = res.message
                            }
                        }) {
                            Text(isTesting ? "Testing..." : "Test Connection")
                        }
                        .buttonStyle(.bordered)
                        .disabled(tuyaAccessId.isEmpty || tuyaAccessSecret.isEmpty || isTesting)
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }

            Section("Atomberg Renesa Fan (Phoenix Cloud API)") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter your Atomberg Developer API credentials to control fan speed, boost, sleep mode, and power:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("X-API-Key")
                            .font(.caption.bold())
                        TextField("Enter Atomberg API Key", text: $atombergApiKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Refresh Token")
                            .font(.caption.bold())
                        SecureField("Enter Atomberg Refresh Token", text: $atombergRefreshToken)
                            .textFieldStyle(.roundedBorder)
                    }

                    if let status = atombergStatus {
                        Text(status)
                            .font(.caption.bold())
                            .foregroundColor(status.contains("success") || status.contains("Connected") ? .green : .orange)
                    }

                    HStack(spacing: 12) {
                        Button(action: {
                            AtombergCloudAdapter.shared.apiKey = atombergApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                            AtombergCloudAdapter.shared.refreshToken = atombergRefreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
                            isAtombergSaved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                isAtombergSaved = false
                            }
                        }) {
                            Label(isAtombergSaved ? "Saved!" : "Save Credentials", systemImage: isAtombergSaved ? "checkmark.circle.fill" : "square.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)

                        Button(action: {
                            isTestingAtomberg = true
                            atombergStatus = nil
                            AtombergCloudAdapter.shared.apiKey = atombergApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                            AtombergCloudAdapter.shared.refreshToken = atombergRefreshToken.trimmingCharacters(in: .whitespacesAndNewlines)

                            Task {
                                do {
                                    let _ = try await AtombergCloudAdapter.shared.getAccessToken()
                                    isTestingAtomberg = false
                                    atombergStatus = "Connected successfully to Atomberg Phoenix Cloud!"
                                } catch {
                                    isTestingAtomberg = false
                                    atombergStatus = error.localizedDescription
                                }
                            }
                        }) {
                            Text(isTestingAtomberg ? "Testing..." : "Test Connection")
                        }
                        .buttonStyle(.bordered)
                        .disabled(atombergApiKey.isEmpty || atombergRefreshToken.isEmpty || isTestingAtomberg)
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }

            Section("Display & Zoom Scale") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Interface Scale")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(round(AppZoomManager.shared.zoomScale * 100)))%")
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        Button("75%") { AppZoomManager.shared.setPinchScale(0.75) }
                            .buttonStyle(.bordered)
                        Button("100% (Default)") { AppZoomManager.shared.resetZoom() }
                            .buttonStyle(.borderedProminent)
                        Button("125%") { AppZoomManager.shared.setPinchScale(1.25) }
                            .buttonStyle(.bordered)
                        Button("150%") { AppZoomManager.shared.setPinchScale(1.50) }
                            .buttonStyle(.bordered)
                    }

                    Text("Tip: You can pinch to zoom with your Mac trackpad, or press **⌘+** / **⌘-** (and **⌘0** to reset) anytime.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Network Discovery") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scan Local Network")
                            .font(.headline)
                        Text("Broadcasts UDP search packets for WiZ, Tuya, and Midea devices")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(manager.isDiscovering ? "Scanning..." : "Scan Now") {
                        manager.discoverDevices()
                    }
                    .disabled(manager.isDiscovering)
                }
            }

            Section("Supported Brands & Protocols") {
                LabeledContent("WiZ Connected", value: "Local UDP (Port 38899) - Instant")
                LabeledContent("Homemate 4-Socket Strip", value: "Tuya Cloud OpenAPI - Live Polling 2.5s")
                LabeledContent("Atomberg Renesa+", value: "Phoenix Cloud API v1")
                LabeledContent("Carrier AI Flexicool", value: "Midea Binary Protocol")
            }

            Section("About Control") {
                LabeledContent("Version", value: "1.0.0 (Native macOS)")
                LabeledContent("Developer", value: "Harikrish Smart Home")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
