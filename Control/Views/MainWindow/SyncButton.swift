import SwiftUI

struct SyncButton: View {
    var manager: DeviceManager
    var showTitle: Bool = false
    @State private var isSpinning: Bool = false
    @State private var rotationAngle: Double = 0
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: startSync) {
            HStack(spacing: 5) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isSpinning || manager.isRefreshing ? .cyan : (isHovered ? .white : Color.white.opacity(0.85)))
                    .rotationEffect(.degrees(rotationAngle))

                if showTitle {
                    Text(isSpinning || manager.isRefreshing ? "Syncing..." : "Sync")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isSpinning || manager.isRefreshing ? .cyan : (isHovered ? .white : Color.white.opacity(0.9)))
                }
            }
            .padding(.horizontal, showTitle ? 9 : 8)
            .padding(.vertical, 5)
            .background(
                isSpinning || manager.isRefreshing
                    ? Color.cyan.opacity(0.2)
                    : (isHovered ? Color.white.opacity(0.14) : Color.white.opacity(0.08))
            )
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(
                    isSpinning || manager.isRefreshing
                        ? Color.cyan.opacity(0.4)
                        : (isHovered ? Color.white.opacity(0.25) : Color.white.opacity(0.12)),
                    lineWidth: 0.8
                )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hovering in
            isHovered = hovering
        }
        .disabled(isSpinning || manager.isRefreshing)
        .keyboardShortcut("r", modifiers: .command)
        .help("Sync device states with phone apps & cloud (⌘R)")
    }

    private func startSync() {
        guard !isSpinning && !manager.isRefreshing else { return }
        HapticFeedback.click()
        isSpinning = true

        withAnimation(.timingCurve(0.2, 0.8, 0.2, 1.0, duration: 0.85)) {
            rotationAngle += 360
        }

        Task {
            let start = Date()
            await manager.refreshAllDevices()
            let elapsed = Date().timeIntervalSince(start)
            if elapsed < 0.85 {
                try? await Task.sleep(nanoseconds: UInt64((0.85 - elapsed) * 1_000_000_000))
            }
            isSpinning = false
        }
    }
}
