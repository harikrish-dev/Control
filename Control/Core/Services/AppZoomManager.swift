import SwiftUI

@MainActor
@Observable
final class AppZoomManager {
    static let shared = AppZoomManager()

    var zoomScale: Double = 1.0 {
        didSet {
            UserDefaults.standard.set(zoomScale, forKey: "app_zoom_scale")
            showBadgeBriefly()
        }
    }

    var isBadgeVisible: Bool = false
    private var hideBadgeTask: Task<Void, Never>? = nil

    init() {
        let saved = UserDefaults.standard.double(forKey: "app_zoom_scale")
        if saved >= 0.70 && saved <= 1.80 {
            self.zoomScale = (saved * 100).rounded() / 100
        } else {
            self.zoomScale = 1.0
        }
    }

    func zoomIn() {
        let next = min(1.80, zoomScale + 0.10)
        withAnimation(.easeOut(duration: 0.2)) {
            zoomScale = (next * 100).rounded() / 100
        }
    }

    func zoomOut() {
        let next = max(0.70, zoomScale - 0.10)
        withAnimation(.easeOut(duration: 0.2)) {
            zoomScale = (next * 100).rounded() / 100
        }
    }

    func resetZoom() {
        withAnimation(.easeOut(duration: 0.2)) {
            zoomScale = 1.0
        }
    }

    func setPinchScale(_ newScale: Double) {
        let clamped = min(1.80, max(0.70, newScale))
        zoomScale = (clamped * 100).rounded() / 100
    }

    private func showBadgeBriefly() {
        withAnimation(.easeOut(duration: 0.15)) {
            isBadgeVisible = true
        }
        hideBadgeTask?.cancel()
        hideBadgeTask = Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if !Task.isCancelled {
                withAnimation(.easeIn(duration: 0.25)) {
                    isBadgeVisible = false
                }
            }
        }
    }
}
