import SwiftUI

struct MuteButton: View {
    @State private var haptic = HapticManager.shared

    var body: some View {
        Button {
            haptic.toggleMute()
        } label: {
            Image(systemName: haptic.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(haptic.isMuted ? Color(red: 1.0, green: 0.45, blue: 0.45) : Color.white.opacity(0.85))
                .frame(width: 28, height: 28)
                .background(haptic.isMuted ? Color.red.opacity(0.18) : Color.white.opacity(0.08))
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(haptic.isMuted ? Color.red.opacity(0.35) : Color.white.opacity(0.12), lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(haptic.isMuted ? "Unmute Click Sounds" : "Mute Click Sounds")
    }
}
