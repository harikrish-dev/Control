import SwiftUI

public struct PlugAnimatedIconView: View {
    public let isOn: Bool
    public var size: CGFloat

    public init(isOn: Bool, size: CGFloat = 36) {
        self.isOn = isOn
        self.size = size
    }

    public var body: some View {
        ZStack {
            // Background halo
            Circle()
                .fill(isOn ? Color(red: 0.2, green: 0.95, blue: 0.5).opacity(0.22) : Color.white.opacity(0.06))
                .frame(width: size, height: size)

            if isOn {
                Circle()
                    .fill(Color(red: 0.2, green: 0.95, blue: 0.5).opacity(0.35))
                    .frame(width: size * 0.75, height: size * 0.75)
                    .blur(radius: 5)
            }

            Canvas { context, sz in
                let midY = sz.height * 0.5
                let plugOffset: CGFloat = isOn ? 0.0 : 6.0
                let plugAngle: Double = isOn ? 0.0 : -0.26 // ~ -15 degrees in radians

                let accent = isOn ? Color(red: 0.2, green: 0.95, blue: 0.5) : Color.white.opacity(0.38)
                let strokeW: CGFloat = 1.2

                // 1. Socket Receptacle on the left
                let socketX: CGFloat = sz.width * 0.20
                let socketW: CGFloat = 10.0
                let socketH: CGFloat = 18.0
                let socketRect = CGRect(x: socketX, y: midY - socketH * 0.5, width: socketW, height: socketH)
                let socketPath = Path(roundedRect: socketRect, cornerRadius: 2.8)

                context.stroke(socketPath, with: .color(accent), lineWidth: strokeW)
                context.fill(socketPath, with: .color(isOn ? Color(red: 0.2, green: 0.95, blue: 0.5).opacity(0.15) : Color.white.opacity(0.05)))

                // Pin slots inside socket
                let slot1 = Path(roundedRect: CGRect(x: socketX + 5.0, y: midY - 5.5, width: 2.0, height: 3.5), cornerRadius: 0.8)
                let slot2 = Path(roundedRect: CGRect(x: socketX + 5.0, y: midY + 2.0, width: 2.0, height: 3.5), cornerRadius: 0.8)
                context.fill(slot1, with: .color(isOn ? Color(red: 0.2, green: 0.95, blue: 0.5) : Color.white.opacity(0.22)))
                context.fill(slot2, with: .color(isOn ? Color(red: 0.2, green: 0.95, blue: 0.5) : Color.white.opacity(0.22)))

                // 2. Plug on the right
                let plugBaseX = socketX + socketW
                let plugX = plugBaseX + plugOffset

                context.withCGContext { cg in
                    if !isOn {
                        // Apply rotation around plug contact center
                        cg.translateBy(x: plugX, y: midY)
                        cg.rotate(by: plugAngle)
                        cg.translateBy(x: -plugX, y: -midY)
                    }

                    // Brass prongs
                    let prongLength: CGFloat = isOn ? 2.5 : 4.5
                    let prongStartX = plugX - (isOn ? 0.0 : prongLength)
                    let pTop = Path(roundedRect: CGRect(x: prongStartX, y: midY - 5.0, width: prongLength, height: 1.8), cornerRadius: 0.6)
                    let pBot = Path(roundedRect: CGRect(x: prongStartX, y: midY + 3.2, width: prongLength, height: 1.8), cornerRadius: 0.6)
                    let prongColor = Color(red: 0.95, green: 0.82, blue: 0.38).opacity(isOn ? 0.9 : 0.7)
                    context.fill(pTop, with: .color(prongColor))
                    context.fill(pBot, with: .color(prongColor))

                    // Plug casing body
                    let plugW: CGFloat = 11.5
                    let plugH: CGFloat = 15.0
                    let plugRect = CGRect(x: plugX, y: midY - plugH * 0.5, width: plugW, height: plugH)
                    let plugPath = Path(roundedRect: plugRect, cornerRadius: 3.0)

                    context.fill(plugPath, with: .color(isOn ? Color(red: 0.15, green: 0.25, blue: 0.20) : Color.white.opacity(0.12)))
                    context.stroke(plugPath, with: .color(accent), lineWidth: strokeW)

                    // Plug grip grooves
                    let g1 = Path(roundedRect: CGRect(x: plugX + 3.5, y: midY - 4.5, width: 1.0, height: 9.0), cornerRadius: 0.5)
                    let g2 = Path(roundedRect: CGRect(x: plugX + 5.5, y: midY - 4.5, width: 1.0, height: 9.0), cornerRadius: 0.5)
                    context.fill(g1, with: .color(Color.white.opacity(0.2)))
                    context.fill(g2, with: .color(Color.white.opacity(0.2)))

                    // Status micro LED on plug
                    let led = Path(ellipseIn: CGRect(x: plugX + plugW - 3.2, y: midY - 1.2, width: 2.4, height: 2.4))
                    context.fill(led, with: .color(isOn ? Color(red: 0.2, green: 1.0, blue: 0.5) : Color.white.opacity(0.2)))

                    // Trailing cord
                    var cord = Path()
                    let cordStart = CGPoint(x: plugX + plugW, y: midY)
                    cord.move(to: cordStart)
                    cord.addCurve(
                        to: CGPoint(x: sz.width - 2, y: midY + 4),
                        control1: CGPoint(x: cordStart.x + 4, y: midY),
                        control2: CGPoint(x: sz.width - 4, y: midY + 4)
                    )
                    context.stroke(cord, with: .color(accent.opacity(0.6)), lineWidth: 1.4)
                }
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isOn)
    }
}

struct DeviceIconView: View {
    @Bindable var device: SmartDevice
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            if device.type == .plug {
                PlugAnimatedIconView(isOn: device.isOn, size: size)
            } else if device.type == .fan {
                ZStack {
                    Circle()
                        .fill(device.isOn ? device.brand.color.opacity(0.22) : Color.white.opacity(0.06))
                        .frame(width: size, height: size)

                    TimelineView(.animation) { timeline in
                        let angle = device.isOn ? (timeline.date.timeIntervalSinceReferenceDate * Double(max(1, device.speed) * 90)).truncatingRemainder(dividingBy: 360) : 0
                        Image(systemName: "fanblades.fill")
                            .font(.system(size: size * 0.47))
                            .foregroundColor(device.isOn ? .cyan : Color.white.opacity(0.35))
                            .rotationEffect(.degrees(angle))
                    }
                }
            } else if device.type == .light {
                ZStack {
                    Circle()
                        .fill(device.isOn ? Color.orange.opacity(0.22) : Color.white.opacity(0.06))
                        .frame(width: size, height: size)

                    if device.isOn {
                        Circle()
                            .fill(Color.orange.opacity(0.45))
                            .frame(width: size * 0.65, height: size * 0.65)
                            .blur(radius: 5)
                    }
                    Image(systemName: device.isOn ? "lightbulb.fill" : "lightbulb")
                        .font(.system(size: size * 0.47))
                        .foregroundColor(device.isOn ? .orange : Color.white.opacity(0.35))
                }
            } else {
                ZStack {
                    Circle()
                        .fill(device.isOn ? device.brand.color.opacity(0.22) : Color.white.opacity(0.06))
                        .frame(width: size, height: size)

                    Image(systemName: device.type.icon)
                        .font(.system(size: size * 0.47))
                        .foregroundColor(device.isOn ? device.brand.color : Color.white.opacity(0.35))
                }
            }
        }
        .frame(width: size, height: size)
    }
}
