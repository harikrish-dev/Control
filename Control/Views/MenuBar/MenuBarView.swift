import SwiftUI
import AppKit

final class MenuBarWindowConfigurator: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configure()
    }

    override func viewWillDraw() {
        super.viewWillDraw()
        configure()
    }

    private func configure() {
        guard let window = self.window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear

        let radius: CGFloat = 18.0

        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = radius
            contentView.layer?.masksToBounds = true
            contentView.layer?.backgroundColor = .clear
        }

        if let frameView = window.contentView?.superview {
            frameView.wantsLayer = true
            frameView.layer?.cornerRadius = radius
            frameView.layer?.masksToBounds = true
            frameView.layer?.backgroundColor = .clear
        }

        window.invalidateShadow()
    }
}

struct WindowConfiguratorView: NSViewRepresentable {
    func makeNSView(context: Context) -> MenuBarWindowConfigurator {
        MenuBarWindowConfigurator()
    }
    func updateNSView(_ nsView: MenuBarWindowConfigurator, context: Context) {
        nsView.needsDisplay = true
    }
}

struct MenuBarView: View {
    @Bindable var manager: DeviceManager
    @State private var activatingSceneId: UUID? = nil

    var activeCount: Int {
        manager.devices.filter { $0.isOn }.count
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(alignment: .center) {
                HStack(spacing: 10) {
                    AppLogoView(size: 32)

                    HStack(spacing: 8) {
                        Text("Control")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        if activeCount > 0 {
                            Text("\(activeCount) ON")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3.5)
                                .background(Color.green.opacity(0.18))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(Color.green.opacity(0.35), lineWidth: 0.8)
                                )
                        }
                    }
                }

                Spacer()

                HStack(spacing: 7) {
                    MuteButton()

                    SyncButton(manager: manager, showTitle: true)

                    Button {
                        HapticFeedback.click()
                        for dev in manager.devices {
                            manager.sendCommand(.power(false), to: dev)
                        }
                    } label: {
                        Text("All Off")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.35))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.red.opacity(0.15))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Color.red.opacity(0.3), lineWidth: 0.8)
                            )
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
            }
            .padding(.horizontal, 4)

            // Quick Scenes
            if !manager.scenes.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    Text("QUICK SCENES")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(Color.white.opacity(0.45))
                        .tracking(0.8)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 9) {
                            ForEach(manager.scenes) { scene in
                                let isAct = (activatingSceneId == scene.id) || (manager.lastActivatedSceneId == scene.id)
                                Button {
                                    HapticFeedback.snap()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        activatingSceneId = scene.id
                                    }
                                    manager.activateScene(scene)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                        if activatingSceneId == scene.id {
                                            withAnimation(.easeInOut(duration: 0.25)) {
                                                activatingSceneId = nil
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 7) {
                                        Image(systemName: isAct ? "checkmark.circle.fill" : scene.icon)
                                            .font(.system(size: 13))
                                            .foregroundColor(isAct ? .green : scene.accentColor)
                                        Text(scene.name)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 13)
                                    .padding(.vertical, 8)
                                    .background(isAct ? Color.green.opacity(0.22) : Color.white.opacity(0.07))
                                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                                            .stroke(isAct ? Color.green.opacity(0.55) : Color.white.opacity(0.10), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            // Devices Section
            VStack(alignment: .leading, spacing: 9) {
                Text("DEVICES")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(Color.white.opacity(0.45))
                    .tracking(0.8)

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 12) {
                        ForEach(manager.devices) { device in
                            MenuBarDeviceRow(device: device) { command in
                                manager.sendCommand(command, to: device)
                            }
                        }
                    }
                    .padding(.trailing, 5)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 24)
        .padding(.bottom, 18)
        .frame(width: 430, height: 615)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.11, green: 0.12, blue: 0.15).opacity(0.97),
                                Color(red: 0.07, green: 0.08, blue: 0.10).opacity(0.98)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.20),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .background(WindowConfiguratorView())
    }
}

struct MenuBarDeviceRow: View {
    @Bindable var device: SmartDevice
    var onCommand: (DeviceCommand) -> Void

    @State private var isRowHovered: Bool = false
    @State private var isExpanded: Bool = false
    @State private var isRenaming: Bool = false
    @State private var editedName: String = ""
    @FocusState private var isNameFocused: Bool
    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 10) {
            headerRow

            if let alertMsg = device.unreachableAlertMessage {
                unreachableAlertPill(msg: alertMsg)
            }

            // If expanded: show all rich options for that device
            if isExpanded {
                expandedControlsSection
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else if device.isOn || device.isPowerStrip {
                // Compact quick controls when collapsed
                compactControlsSection
            }
        }
        .padding(14)
        .offset(x: shakeOffset)
        .background(
            DeviceAnimatedBackground(device: device, cornerRadius: 14, isDarkTheme: true, isHovered: isRowHovered)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    !device.isOnline
                        ? device.unreachableColor.opacity(0.4)
                        : (device.isOn ? device.brand.color.opacity(0.4) : Color.white.opacity(0.08)),
                    lineWidth: 1
                )
        )
        .onHover { hovering in
            isRowHovered = hovering
        }
        .onChange(of: device.unreachableTrigger) { _, _ in
            triggerShakeAnimation()
        }
        .contextMenu {
            Button {
                startRename()
            } label: {
                Label("Rename Device", systemImage: "pencil")
            }
        }
    }

    private func togglePower() {
        if !device.isOnline {
            device.triggerUnreachableAlert()
            return
        }
        HapticFeedback.click()
        device.lastActionDate = Date()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            onCommand(.power(!device.isOn))
        }
    }

    private func startRename() {
        editedName = device.name
        isRenaming = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isNameFocused = true
        }
    }

    private func commitRename() {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != device.name {
            device.name = trimmed
            DeviceManager.shared.saveDevices()
            HapticFeedback.snap()
        }
        isRenaming = false
    }

    private func triggerShakeAnimation() {
        withAnimation(.spring(response: 0.10, dampingFraction: 0.2)) {
            shakeOffset = 6
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.spring(response: 0.10, dampingFraction: 0.2)) {
                shakeOffset = -6
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            withAnimation(.spring(response: 0.12, dampingFraction: 0.25)) {
                shakeOffset = 4
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
                shakeOffset = 0
            }
        }
    }

    @ViewBuilder
    private func unreachableAlertPill(msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: device.unreachableIcon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(device.unreachableColor)
                .symbolEffect(.bounce, value: device.unreachableTrigger)

            VStack(alignment: .leading, spacing: 1) {
                Text(device.unreachableTitle)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Text(msg)
                    .font(.system(size: 9.5))
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(red: 0.12, green: 0.08, blue: 0.10).opacity(0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(device.unreachableColor.opacity(0.8), lineWidth: 1)
        )
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            // Left Button (Animated Icon + Quick Power Toggle)
            Button {
                togglePower()
            } label: {
                DeviceIconView(device: device, size: 36)
            }
            .buttonStyle(.plain)
            .focusable(false)

            if isRenaming {
                HStack(spacing: 4) {
                    TextField("Device Name", text: $editedName)
                        .font(.system(size: 12, weight: .bold))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(device.brand.color, lineWidth: 1)
                        )
                        .focused($isNameFocused)
                        .onSubmit {
                            commitRename()
                        }
                        .onExitCommand {
                            isRenaming = false
                        }

                    Button {
                        commitRename()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)

                    Button {
                        isRenaming = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(device.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Image(systemName: "pencil")
                            .font(.system(size: 9))
                            .foregroundColor(Color.white.opacity(0.35))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        startRename()
                    }
                    .help("Click to rename device")

                    HStack(spacing: 4) {
                        if !device.isOnline {
                            Circle()
                                .fill(device.unreachableColor)
                                .frame(width: 4.5, height: 4.5)
                            Text(device.statusText)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(device.unreachableColor)
                        } else {
                            Text(device.statusText)
                                .font(.system(size: 11))
                                .foregroundColor(Color.white.opacity(0.5))
                        }
                    }
                }
            }

            Spacer()

            // Expand / Collapse Options Chevron
            Button {
                HapticFeedback.click()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(isExpanded ? .cyan : Color.white.opacity(0.45))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 26, height: 26)
                    .background(isExpanded ? Color.cyan.opacity(0.18) : Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            powerButton
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isRenaming {
                HapticFeedback.click()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    isExpanded.toggle()
                }
            }
        }
    }

    private var powerButton: some View {
        Button {
            togglePower()
        } label: {
            Image(systemName: "power")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(device.isOn ? .white : Color.white.opacity(0.4))
                .frame(width: 30, height: 30)
                .background(device.isOn ? device.brand.color : Color.white.opacity(0.08))
                .clipShape(Circle())
                .shadow(color: device.isOn ? device.brand.color.opacity(0.5) : Color.clear, radius: 5, x: 0, y: 1)
                .overlay(
                    Circle().stroke(device.isOn ? Color.white.opacity(0.2) : Color.white.opacity(0.08), lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Compact Quick Controls (when collapsed and ON)
    @ViewBuilder
    private var compactControlsSection: some View {
        if device.type == .fan {
            compactFanControls
        } else if device.type == .light {
            compactLightControls
        } else if device.isPowerStrip {
            compactPowerStripControls
        } else if device.type == .airConditioner {
            compactACControls
        }
    }

    private var compactFanControls: some View {
        HStack(spacing: 6) {
            Text("Speed")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.white.opacity(0.5))
            Spacer()
            ForEach(1...6, id: \.self) { spd in
                Button {
                    HapticFeedback.snap()
                    device.lastActionDate = Date()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        device.speed = spd
                        onCommand(.fanSpeed(spd))
                    }
                } label: {
                    Text("\(spd)")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 22, height: 22)
                        .background(device.speed == spd ? Color.cyan : Color.white.opacity(0.08))
                        .foregroundColor(device.speed == spd ? .black : Color.white.opacity(0.7))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 2)
    }

    private var compactLightControls: some View {
        HStack(spacing: 8) {
            Image(systemName: "sun.min.fill")
                .font(.system(size: 10))
                .foregroundColor(Color.white.opacity(0.4))

            Slider(
                value: Binding(
                    get: { Double(device.brightness) },
                    set: { newVal in
                        let intVal = Int(newVal)
                        if abs(intVal - device.brightness) >= 2 {
                            HapticFeedback.levelChange()
                        }
                        device.lastActionDate = Date()
                        device.brightness = intVal
                        onCommand(.brightness(intVal))
                    }
                ),
                in: 10...100
            )
            .controlSize(.mini)
            .tint(.orange)

            Image(systemName: "sun.max.fill")
                .font(.system(size: 11))
                .foregroundColor(.orange)

            Text("\(device.brightness)%")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.top, 2)
    }

    private var compactPowerStripControls: some View {
        HStack(spacing: 8) {
            ForEach(0..<min(device.socketCount, device.socketStates.count), id: \.self) { idx in
                let isSocketOn = device.socketStates[idx]
                Button {
                    HapticFeedback.click()
                    let newState = !isSocketOn
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                        device.setSocketStateOptimistic(socketIndex: idx + 1, isOn: newState)
                        onCommand(.socketPower(socketIndex: idx + 1, isOn: newState))
                    }
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(isSocketOn ? Color.green : Color.white.opacity(0.2))
                            .frame(width: 6, height: 6)
                            .shadow(color: isSocketOn ? Color.green.opacity(0.9) : Color.clear, radius: 3)

                        Text("S\(idx + 1)")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(isSocketOn ? Color.green.opacity(0.2) : Color.white.opacity(0.06))
                    .foregroundColor(isSocketOn ? Color(red: 0.4, green: 1.0, blue: 0.6) : Color.white.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
        }
        .padding(.top, 2)
    }

    private var compactACControls: some View {
        HStack(spacing: 8) {
            Text("Target Temp")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.white.opacity(0.5))

            Spacer()

            Button {
                HapticFeedback.snap()
                device.lastActionDate = Date()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    let newTemp = max(16.0, device.targetTemperature - 1.0)
                    device.targetTemperature = newTemp
                    onCommand(.acTemperature(newTemp))
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Text(String(format: "%.0f°C", device.targetTemperature))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.cyan)
                .monospacedDigit()
                .frame(width: 38)

            Button {
                HapticFeedback.snap()
                device.lastActionDate = Date()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    let newTemp = min(30.0, device.targetTemperature + 1.0)
                    device.targetTemperature = newTemp
                    onCommand(.acTemperature(newTemp))
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
    }

    // MARK: - Rich Expanded Controls Section (Full App Options in Popup)
    @ViewBuilder
    private var expandedControlsSection: some View {
        VStack(spacing: 12) {
            Divider()
                .background(Color.white.opacity(0.12))

            switch device.type {
            case .fan:
                MenuBarFanExpandedView(device: device, onCommand: onCommand)
            case .light:
                MenuBarLightExpandedView(device: device, onCommand: onCommand)
            case .plug:
                MenuBarPlugExpandedView(device: device, onCommand: onCommand)
            case .airConditioner:
                MenuBarACExpandedView(device: device, onCommand: onCommand)
            }
        }
    }
}

// MARK: - 1. Fan Expanded Controls View (All App Options)
struct MenuBarFanExpandedView: View {
    @Bindable var device: SmartDevice
    var onCommand: (DeviceCommand) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            speedSection
            modesSection
            timerSection
        }
        .padding(10)
        .background(Color.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var speedSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("FAN SPEED")
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(Color.white.opacity(0.45))
                .tracking(0.6)

            HStack(spacing: 6) {
                ForEach(1...6, id: \.self) { spd in
                    Button {
                        HapticFeedback.snap()
                        device.lastActionDate = Date()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            device.speed = spd
                            device.isBoostMode = false
                            onCommand(.fanSpeed(spd))
                        }
                    } label: {
                        Text("\(spd)")
                            .font(.system(size: 11, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 26)
                            .background(device.speed == spd && !device.isBoostMode ? Color.cyan : Color.white.opacity(0.08))
                            .foregroundColor(device.speed == spd && !device.isBoostMode ? .black : Color.white.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var modesSection: some View {
        HStack(spacing: 8) {
            Button {
                HapticFeedback.click()
                device.lastActionDate = Date()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    let newBoost = !device.isBoostMode
                    device.isBoostMode = newBoost
                    if newBoost { device.isSleepMode = false }
                    onCommand(.fanBoost(newBoost))
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                    Text("Boost")
                        .font(.system(size: 11, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(device.isBoostMode ? Color.orange : Color.white.opacity(0.08))
                .foregroundColor(device.isBoostMode ? .black : Color.white.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                HapticFeedback.click()
                device.lastActionDate = Date()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    let newSleep = !device.isSleepMode
                    device.isSleepMode = newSleep
                    if newSleep { device.isBoostMode = false }
                    onCommand(.fanSleep(newSleep))
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 10))
                    Text("Sleep")
                        .font(.system(size: 11, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(device.isSleepMode ? Color.indigo : Color.white.opacity(0.08))
                .foregroundColor(device.isSleepMode ? .white : Color.white.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                device.lastActionDate = Date()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    let newLed = !device.isLedOn
                    device.isLedOn = newLed
                    onCommand(.fanLed(newLed))
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: device.isLedOn ? "lightbulb.fill" : "lightbulb")
                        .font(.system(size: 10))
                    Text("LED")
                        .font(.system(size: 11, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(device.isLedOn ? Color.yellow.opacity(0.2) : Color.white.opacity(0.08))
                .foregroundColor(device.isLedOn ? .yellow : Color.white.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("TIMER")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(Color.white.opacity(0.45))
                    .tracking(0.6)
                Spacer()
                if device.timerMinutes > 0 {
                    Text("\(device.timerMinutes / 60)h Active")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.cyan)
                }
            }

            HStack(spacing: 6) {
                ForEach([1, 2, 3, 6], id: \.self) { hrs in
                    let isSelected = device.timerMinutes == hrs * 60
                    Button {
                        HapticFeedback.snap()
                        device.lastActionDate = Date()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            device.timerMinutes = hrs * 60
                            onCommand(.fanTimer(hrs * 60))
                        }
                    } label: {
                        Text("\(hrs)h")
                            .font(.system(size: 10, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(isSelected ? Color.cyan.opacity(0.25) : Color.white.opacity(0.07))
                            .foregroundColor(isSelected ? .cyan : Color.white.opacity(0.75))
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(isSelected ? Color.cyan.opacity(0.5) : Color.clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                if device.timerMinutes > 0 {
                    Button {
                        HapticFeedback.click()
                        device.lastActionDate = Date()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            device.timerMinutes = 0
                            onCommand(.fanTimer(0))
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .frame(width: 26, height: 24)
                            .background(Color.red.opacity(0.18))
                            .foregroundColor(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - 2. Light Expanded Controls View (All App Options)
struct MenuBarLightExpandedView: View {
    @Bindable var device: SmartDevice
    var onCommand: (DeviceCommand) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            brightnessSection
            colorTempSection
            colorPaletteSection
            scenesSection
        }
        .padding(10)
        .background(Color.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var brightnessSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Brightness", systemImage: "sun.max.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.6))
                Spacer()
                Text("\(device.brightness)%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
                    .monospacedDigit()
            }

            Slider(
                value: Binding(
                    get: { Double(device.brightness) },
                    set: { val in
                        let intVal = Int(val)
                        if abs(intVal - device.brightness) >= 2 {
                            HapticFeedback.levelChange()
                        }
                        device.lastActionDate = Date()
                        device.brightness = intVal
                        onCommand(.brightness(intVal))
                    }
                ),
                in: 10...100
            )
            .controlSize(.mini)
            .tint(.orange)
        }
    }

    private var colorTempSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Color Temperature", systemImage: "thermometer.medium")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.6))
                Spacer()
                Text("\(device.colorTemperature)K")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.4))
                    .monospacedDigit()
            }

            Slider(
                value: Binding(
                    get: { Double(device.colorTemperature) },
                    set: { val in
                        let intVal = Int(val)
                        if abs(intVal - device.colorTemperature) >= 80 {
                            HapticFeedback.levelChange()
                        }
                        device.lastActionDate = Date()
                        device.colorTemperature = intVal
                        onCommand(.colorTemperature(intVal))
                    }
                ),
                in: 2200...6500,
                step: 50
            )
            .controlSize(.mini)
            .tint(Color(red: 1.0, green: 0.75, blue: 0.3))

            HStack(spacing: 6) {
                ForEach([("Warm", 2700), ("Neutral", 4000), ("Cool", 6500)], id: \.1) { name, temp in
                    Button {
                        HapticFeedback.snap()
                        device.lastActionDate = Date()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            device.colorTemperature = temp
                            onCommand(.colorTemperature(temp))
                        }
                    } label: {
                        Text(name)
                            .font(.system(size: 9, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(device.colorTemperature == temp ? Color.white.opacity(0.18) : Color.white.opacity(0.06))
                            .foregroundColor(Color.white.opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var colorPaletteSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("COLOR PALETTE")
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(Color.white.opacity(0.45))
                .tracking(0.6)

            HStack(spacing: 8) {
                let palette: [(Color, Int, Int, Int)] = [
                    (Color(red: 1.0, green: 0.96, blue: 0.90), 255, 244, 229),
                    (Color(red: 1.0, green: 0.75, blue: 0.20), 255, 191, 51),
                    (Color(red: 1.0, green: 0.40, blue: 0.15), 255, 102, 38),
                    (Color(red: 0.20, green: 0.90, blue: 1.00), 51, 229, 255),
                    (Color(red: 0.25, green: 0.50, blue: 1.00), 64, 128, 255),
                    (Color(red: 0.75, green: 0.35, blue: 1.00), 191, 89, 255),
                    (Color(red: 0.20, green: 0.95, blue: 0.55), 51, 242, 140),
                    (Color(red: 1.00, green: 0.25, blue: 0.40), 255, 64, 102)
                ]
                ForEach(0..<palette.count, id: \.self) { idx in
                    let item = palette[idx]
                    let isSelected = device.red == item.1 && device.green == item.2 && device.blue == item.3
                    Button {
                        HapticFeedback.snap()
                        device.lastActionDate = Date()
                        device.red = item.1
                        device.green = item.2
                        device.blue = item.3
                        onCommand(.rgb(r: item.1, g: item.2, b: item.3))
                    } label: {
                        Circle()
                            .fill(item.0)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle().stroke(isSelected ? Color.white : Color.white.opacity(0.35), lineWidth: isSelected ? 2.0 : 1.2)
                            )
                            .shadow(color: item.0.opacity(isSelected ? 0.8 : 0.4), radius: isSelected ? 5 : 3)
                            .scaleEffect(isSelected ? 1.12 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .padding(.vertical, 4)
    }

    private var scenesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MOOD SCENES")
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(Color.white.opacity(0.45))
                .tracking(0.6)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(WiZScenes.scenes.prefix(8), id: \.id) { sc in
                    let isCur = device.currentScene == sc.name
                    Button {
                        HapticFeedback.snap()
                        device.lastActionDate = Date()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            device.currentScene = sc.name
                            onCommand(.scene(sc.name))
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: sc.icon)
                                .font(.system(size: 11))
                                .foregroundColor(isCur ? .orange : Color.white.opacity(0.7))
                            Text(sc.name)
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(isCur ? .white : Color.white.opacity(0.6))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(isCur ? Color.orange.opacity(0.25) : Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(isCur ? Color.orange.opacity(0.6) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - 3. Plug Expanded Controls View (All App Options)
struct MenuBarPlugExpandedView: View {
    @Bindable var device: SmartDevice
    var onCommand: (DeviceCommand) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            masterBanner
            socketsList
            metricsRow
        }
        .padding(10)
        .background(Color.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var masterBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("MASTER SWITCH")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(Color.white.opacity(0.45))
                    .tracking(0.6)
                Text(device.isOn ? "All Active" : "Switched Off")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(device.isOn ? .green : Color.white.opacity(0.5))
            }
            Spacer()
            Button {
                HapticFeedback.click()
                let newState = !device.isOn
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    device.setAllSocketsOptimistic(isOn: newState)
                    onCommand(.power(newState))
                }
            } label: {
                Text(device.isOn ? "Turn Off All" : "Turn On All")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(device.isOn ? Color(red: 1.0, green: 0.4, blue: 0.4) : .green)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(device.isOn ? Color.red.opacity(0.15) : Color.green.opacity(0.18))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .focusable(false)
        }
    }

    private var socketsList: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("INDIVIDUAL SOCKETS")
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(Color.white.opacity(0.45))
                .tracking(0.6)

            ForEach(0..<min(device.socketCount, device.socketStates.count), id: \.self) { idx in
                let isSocketOn = device.socketStates[idx]
                let sockName = idx < device.socketNames.count ? device.socketNames[idx] : "Socket \(idx + 1)"

                HStack {
                    Circle()
                        .fill(isSocketOn ? Color.green : Color.white.opacity(0.2))
                        .frame(width: 7, height: 7)
                        .shadow(color: isSocketOn ? Color.green.opacity(0.9) : Color.clear, radius: 3)

                    Text(sockName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)

                    Spacer()

                    Button {
                        HapticFeedback.click()
                        let newState = !isSocketOn
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                            device.setSocketStateOptimistic(socketIndex: idx + 1, isOn: newState)
                            onCommand(.socketPower(socketIndex: idx + 1, isOn: newState))
                        }
                    } label: {
                        Text(isSocketOn ? "ON" : "OFF")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(isSocketOn ? Color(red: 0.4, green: 1.0, blue: 0.6) : Color.white.opacity(0.4))
                            .frame(width: 38, height: 20)
                            .background(isSocketOn ? Color.green.opacity(0.22) : Color.white.opacity(0.06))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(isSocketOn ? Color.green.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 0.8)
                            )
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "gauge")
                    .font(.system(size: 10))
                    .foregroundColor(.cyan)
                VStack(alignment: .leading, spacing: 0) {
                    Text("VOLTAGE")
                        .font(.system(size: 7, weight: .heavy))
                        .foregroundColor(Color.white.opacity(0.45))
                    Text(device.currentVoltage != nil ? String(format: "%.1f V", device.currentVoltage!) : "— V")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(spacing: 5) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 0) {
                    Text("LOAD")
                        .font(.system(size: 7, weight: .heavy))
                        .foregroundColor(Color.white.opacity(0.45))
                    Text(device.currentPower != nil ? String(format: "%.1f W", device.currentPower!) : (device.isOn ? "— W" : "0.0 W"))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(device.isOn ? Color(red: 0.4, green: 1.0, blue: 0.6) : Color.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(spacing: 5) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 0) {
                    Text("CURRENT")
                        .font(.system(size: 7, weight: .heavy))
                        .foregroundColor(Color.white.opacity(0.45))
                    Text(device.currentCurrent != nil ? String(format: "%.2f A", device.currentCurrent!) : (device.isOn ? "— A" : "0.00 A"))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

// MARK: - 4. AC Expanded Controls View (All App Options)
struct MenuBarACExpandedView: View {
    @Bindable var device: SmartDevice
    var onCommand: (DeviceCommand) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            tempRow
            modeRow
            extrasRow
        }
        .padding(10)
        .background(Color.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var tempRow: some View {
        HStack {
            Text("TARGET TEMP")
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(Color.white.opacity(0.45))
                .tracking(0.6)
            Spacer()
            Button {
                device.lastActionDate = Date()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    let newTemp = max(16.0, device.targetTemperature - 0.5)
                    device.targetTemperature = newTemp
                    onCommand(.acTemperature(newTemp))
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color.white.opacity(0.6))
            }
            .buttonStyle(.plain)

            Text(String(format: "%.1f°C", device.targetTemperature))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.cyan)
                .monospacedDigit()
                .frame(width: 60)

            Button {
                device.lastActionDate = Date()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    let newTemp = min(30.0, device.targetTemperature + 0.5)
                    device.targetTemperature = newTemp
                    onCommand(.acTemperature(newTemp))
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.cyan)
            }
            .buttonStyle(.plain)
        }
    }

    private var modeRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MODE")
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(Color.white.opacity(0.45))
                .tracking(0.6)

            HStack(spacing: 6) {
                ForEach(ACMode.allCases) { mode in
                    let isCur = device.acMode == mode
                    Button {
                        device.lastActionDate = Date()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            device.acMode = mode
                            onCommand(.acMode(mode))
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 10))
                            Text(mode.displayName)
                                .font(.system(size: 8, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(isCur ? Color.cyan : Color.white.opacity(0.07))
                        .foregroundColor(isCur ? .black : Color.white.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var extrasRow: some View {
        HStack(spacing: 8) {
            Button {
                device.lastActionDate = Date()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    device.isSwingOn.toggle()
                    onCommand(.acSwing(device.isSwingOn))
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "wind")
                        .font(.system(size: 9))
                    Text("Swing")
                        .font(.system(size: 10, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(device.isSwingOn ? Color.cyan.opacity(0.25) : Color.white.opacity(0.07))
                .foregroundColor(device.isSwingOn ? .cyan : Color.white.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                device.lastActionDate = Date()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    device.isTurbo.toggle()
                    onCommand(.acTurbo(device.isTurbo))
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9))
                    Text("Turbo")
                        .font(.system(size: 10, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(device.isTurbo ? Color.orange : Color.white.opacity(0.07))
                .foregroundColor(device.isTurbo ? .black : Color.white.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                device.lastActionDate = Date()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    device.isEco.toggle()
                    onCommand(.acEco(device.isEco))
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 9))
                    Text("Eco")
                        .font(.system(size: 10, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(device.isEco ? Color.green : Color.white.opacity(0.07))
                .foregroundColor(device.isEco ? .black : Color.white.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}
