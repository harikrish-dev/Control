import SwiftUI

enum NavigationItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case rooms = "Rooms"
    case scenes = "Scenes"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .rooms: return "house.fill"
        case .scenes: return "sparkles"
        case .settings: return "gearshape.fill"
        }
    }
}

struct ContentView: View {
    @State private var manager = DeviceManager.shared
    @State private var zoomManager = AppZoomManager.shared
    @State private var selectedTab: NavigationItem = .dashboard
    @State private var showAddDeviceSheet = false
    @State private var initialPinchScale: Double = 1.0
    @State private var showSplash: Bool = true

    var body: some View {
        ZStack {
            NavigationSplitView {
            List(selection: $selectedTab) {
                Section {
                    ForEach(NavigationItem.allCases) { item in
                        NavigationLink(value: item) {
                            Label(item.rawValue, systemImage: item.icon)
                        }
                    }
                } header: {
                    HStack(spacing: 8) {
                        AppLogoView(size: 22, cornerRadius: 5)
                        Text("Control")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.sidebar)
        } detail: {
            GeometryReader { geo in
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        switch selectedTab {
                        case .dashboard:
                            DashboardView(manager: manager)
                        case .rooms:
                            RoomsView(manager: manager)
                        case .scenes:
                            ScenesView(manager: manager)
                        case .settings:
                            SettingsView(manager: manager)
                        }
                    }
                    .frame(
                        width: max(100, geo.size.width / zoomManager.zoomScale),
                        height: max(100, geo.size.height / zoomManager.zoomScale)
                    )
                    .scaleEffect(zoomManager.zoomScale, anchor: .topLeading)

                    // Floating Zoom HUD Badge (auto-hides after 1.4s)
                    if zoomManager.isBadgeVisible {
                        HStack(spacing: 7) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)

                            Text("\(Int(round(zoomManager.zoomScale * 100)))%")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .background(Color.black.opacity(0.55))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .padding(20)
                    }
                }
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let target = initialPinchScale * value
                            zoomManager.setPinchScale(target)
                        }
                        .onEnded { _ in
                            initialPinchScale = zoomManager.zoomScale
                        }
                )
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    SyncButton(manager: manager, showTitle: false)
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddDeviceSheet = true
                    } label: {
                        Label("Add Device", systemImage: "plus")
                    }
                    .help("Add or connect a new smart home device")
                }
            }
        }
        .sheet(isPresented: $showAddDeviceSheet) {
            AddDeviceSheet(manager: manager)
        }
        .frame(minWidth: 840, minHeight: 540)

            if showSplash {
                AppLoadingSplashView {
                    withAnimation(.easeOut(duration: 0.45)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(999)
            }
        }
    }
}
