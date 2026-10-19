import SwiftUI
import AppKit

@main
struct ControlApp: App {
    @State private var manager = DeviceManager.shared
    @State private var zoomManager = AppZoomManager.shared

    init() {
        if let icon = AppLogoImage.rawImage {
            NSApplication.shared.applicationIconImage = icon
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .toolbar) {
                Divider()
                Button("Zoom In") {
                    zoomManager.zoomIn()
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Zoom In (Equals)") {
                    zoomManager.zoomIn()
                }
                .keyboardShortcut("=", modifiers: .command)

                Button("Zoom Out") {
                    zoomManager.zoomOut()
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Actual Size") {
                    zoomManager.resetZoom()
                }
                .keyboardShortcut("0", modifiers: .command)
            }
        }

        MenuBarExtra {
            MenuBarView(manager: manager)
        } label: {
            Image(nsImage: AppLogoImage.menuBarMonochromeC)
        }
        .menuBarExtraStyle(.window)
    }
}
