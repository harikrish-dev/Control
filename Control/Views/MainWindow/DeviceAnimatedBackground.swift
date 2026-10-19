import SwiftUI

struct DeviceAnimatedBackground: View {
    @Bindable var device: SmartDevice
    var cornerRadius: CGFloat = 14
    var isDarkTheme: Bool = false
    var isHovered: Bool = false

    @State private var localHover: Bool = false
    @State private var isActionActive: Bool = false
    @State private var actionTask: Task<Void, Never>? = nil

    private var shouldAnimate: Bool {
        isHovered || localHover || isActionActive
    }

    var body: some View {
        ZStack {
            // Base background
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(isDarkTheme ? Color.white.opacity(0.055) : Color(nsColor: .controlBackgroundColor))

            if shouldAnimate {
                TimelineView(.animation) { timeline in
                    let elapsed = max(0.0, timeline.date.timeIntervalSince(device.lastActionDate))
                    let isHovering = isHovered || localHover
                    let fadeOpacity: Double = (isHovering && !isActionActive) ? 1.0 : (elapsed < 2.2 ? 1.0 : max(0.0, (3.0 - elapsed) / 0.8))

                    activeAnimationLayer(time: timeline.date.timeIntervalSinceReferenceDate)
                        .opacity(fadeOpacity)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(
            color: shouldAnimate ? shadowColor.opacity(isDarkTheme ? 0.22 : 0.14) : Color.clear,
            radius: 6,
            x: 0,
            y: 0
        )
        .onHover { hovering in
            localHover = hovering
        }
        .onChange(of: device.lastActionDate) { _, _ in
            startActionTimer()
        }
    }

    private var shadowColor: Color {
        switch device.type {
        case .fan:
            return .cyan
        case .light:
            return .orange
        case .plug:
            return device.isOn ? Color(red: 0.1, green: 0.95, blue: 0.45) : Color(red: 1.0, green: 0.5, blue: 0.15)
        case .airConditioner:
            return .blue
        }
    }

    private func startActionTimer() {
        actionTask?.cancel()
        isActionActive = true
        actionTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            if !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.25)) {
                    isActionActive = false
                }
            }
        }
    }

    @ViewBuilder
    private func activeAnimationLayer(time: TimeInterval) -> some View {
        switch device.type {
        case .fan:
            FanAirFlowView(
                speed: device.speed,
                isOn: device.isOn,
                isDarkTheme: isDarkTheme,
                time: time
            )
        case .light:
            LightRadiantGlowView(
                isOn: device.isOn,
                brightness: device.brightness,
                isDarkTheme: isDarkTheme,
                time: time
            )
        case .plug:
            PlugAmbientEnergyView(
                isOn: device.isOn,
                isDarkTheme: isDarkTheme,
                time: time
            )
        case .airConditioner:
            ACCoolingWaveView(
                isOn: device.isOn,
                isDarkTheme: isDarkTheme,
                time: time
            )
        }
    }
}

// MARK: - 1. Plug Ambient Energy Glow (Subtle & Completely Non-Distracting)
struct PlugAmbientEnergyView: View {
    let isOn: Bool
    let isDarkTheme: Bool
    let time: TimeInterval

    var body: some View {
        let t = time * 1.5
        let pulse: Double = (sin(t) + 1.0) / 2.0
        let baseOpacity = isOn ? (isDarkTheme ? 0.16 : 0.10) : 0.03
        let glowOpacity: Double = baseOpacity + (isOn ? pulse * 0.08 : 0.0)

        ZStack {
            RadialGradient(
                colors: [
                    Color(red: 0.15, green: 0.95, blue: 0.5).opacity(glowOpacity),
                    Color(red: 0.10, green: 0.75, blue: 0.4).opacity(glowOpacity * 0.4),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 6,
                endRadius: 130
            )

            LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0.95, blue: 0.5).opacity(isOn ? (isDarkTheme ? 0.08 : 0.05) : 0.01),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - 2. Fan Air Flow Animation
struct FanAirFlowView: View {
    let speed: Int
    let isOn: Bool
    let isDarkTheme: Bool
    let time: TimeInterval

    var body: some View {
        let speedMultiplier = isOn ? max(1.0, Double(speed) * 0.9) : 0.4
        let t = time * speedMultiplier

        ZStack {
            LinearGradient(
                colors: [
                    Color.cyan.opacity(isOn ? (isDarkTheme ? 0.20 : 0.14) : 0.05),
                    Color.blue.opacity(isOn ? (isDarkTheme ? 0.10 : 0.06) : 0.02),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            Canvas { context, size in
                let w = size.width
                let h = size.height

                for i in 0..<3 {
                    var path = Path()
                    let yBase = h * (0.28 + Double(i) * 0.26)
                    let phase = t * 2.2 + Double(i) * 1.8
                    path.move(to: CGPoint(x: -20, y: yBase + sin(phase) * 5.0))

                    var x: Double = -20
                    while x <= w + 30 {
                        let waveY = yBase + sin((x / 38.0) - phase) * (6.0 + Double(i) * 2.0)
                        path.addLine(to: CGPoint(x: x, y: waveY))
                        x += 10.0
                    }

                    let streamColor: Color = (i == 1) ? Color(red: 0.2, green: 0.85, blue: 1.0) : Color.cyan
                    let startP = CGPoint(x: 0, y: yBase)
                    let endP = CGPoint(x: w, y: yBase)
                    let alpha = isOn ? (isDarkTheme ? 0.55 : 0.38) : 0.15

                    let gradient = Gradient(colors: [
                        streamColor.opacity(0.0),
                        streamColor.opacity(alpha * 0.7),
                        streamColor.opacity(alpha),
                        streamColor.opacity(0.0)
                    ])

                    context.stroke(
                        path,
                        with: .linearGradient(gradient, startPoint: startP, endPoint: endP),
                        lineWidth: 2.2
                    )
                }
            }
        }
    }
}

// MARK: - 3. Light Radiant Warm Glow Animation
struct LightRadiantGlowView: View {
    let isOn: Bool
    let brightness: Int
    let isDarkTheme: Bool
    let time: TimeInterval

    var body: some View {
        let t = time * 1.6
        let pulse: Double = (sin(t) + 1.0) / 2.0
        let baseOpacity = isOn ? (isDarkTheme ? 0.26 : 0.18) : 0.06
        let glowOpacity: Double = baseOpacity + (isOn ? pulse * 0.14 : 0.0)
        let glowRadius: Double = 70.0 + (isOn ? pulse * 45.0 : 0.0)

        ZStack {
            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.65, blue: 0.15).opacity(glowOpacity),
                    Color(red: 1.0, green: 0.82, blue: 0.30).opacity(glowOpacity * 0.5),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 8,
                endRadius: glowRadius * 2.0
            )

            LinearGradient(
                colors: [
                    Color.orange.opacity(isOn ? (isDarkTheme ? 0.14 : 0.08) : 0.02),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - 4. AC Cooling Wave Animation
struct ACCoolingWaveView: View {
    let isOn: Bool
    let isDarkTheme: Bool
    let time: TimeInterval

    var body: some View {
        let t = time * 1.2

        ZStack {
            LinearGradient(
                colors: [
                    Color.cyan.opacity(isOn ? (isDarkTheme ? 0.18 : 0.12) : 0.04),
                    Color(red: 0.4, green: 0.7, blue: 1.0).opacity(isOn ? (isDarkTheme ? 0.09 : 0.05) : 0.02),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Canvas { context, size in
                let w = size.width
                let h = size.height
                for i in 0..<2 {
                    var wave = Path()
                    let yBase = h * (0.6 + Double(i) * 0.2)
                    wave.move(to: CGPoint(x: 0, y: yBase))
                    var x = 0.0
                    while x <= w {
                        let y = yBase + sin((x / 30.0) + t + Double(i)) * 4.0
                        wave.addLine(to: CGPoint(x: x, y: y))
                        x += 10.0
                    }
                    context.stroke(wave, with: .color(Color.cyan.opacity(isOn ? 0.30 : 0.10)), lineWidth: 1.5)
                }
            }
        }
    }
}
