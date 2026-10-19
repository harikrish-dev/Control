import SwiftUI

struct ScenesView: View {
    @Bindable var manager: DeviceManager
    @State private var activatingSceneId: UUID? = nil
    @State private var editingScene: SmartScene? = nil
    @State private var isCreatingNewScene: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Automation Scenes")
                            .font(.title2.bold())
                        Text("One-tap control across all your smart lights, fans, plugs, and air conditioners.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button {
                        isCreatingNewScene = true
                    } label: {
                        Label("Add Scene", systemImage: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundColor(.accentColor)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // Scenes Grid
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 18)], spacing: 18) {
                    ForEach(manager.scenes) { scene in
                        let isAct = (activatingSceneId == scene.id) || (manager.lastActivatedSceneId == scene.id)
                        
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top) {
                                Image(systemName: scene.icon)
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 46, height: 46)
                                    .background(scene.accentColor)
                                    .clipShape(Circle())
                                    .shadow(color: scene.accentColor.opacity(0.35), radius: 6, x: 0, y: 3)

                                Spacer()

                                Button {
                                    triggerScene(scene)
                                } label: {
                                    HStack(spacing: 5) {
                                        if isAct {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                            Text("Activated")
                                                .font(.caption.bold())
                                        } else {
                                            Text("Activate")
                                                .font(.caption.bold())
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(isAct ? Color.green : scene.accentColor.opacity(0.15))
                                    .foregroundColor(isAct ? .white : scene.accentColor)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(scene.name)
                                        .font(.headline)
                                    if scene.isCustom {
                                        Text("Custom")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.15))
                                            .foregroundColor(.secondary)
                                            .clipShape(Capsule())
                                    }
                                }

                                Text(scene.subtitle)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            // Device targets hint
                            HStack(spacing: 6) {
                                sceneTargetBadges(for: scene)
                                Spacer()
                                
                                Button {
                                    editingScene = scene
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.secondary.opacity(0.7))
                                        .padding(6)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(isAct ? Color.green.opacity(0.6) : Color.white.opacity(0.06), lineWidth: isAct ? 1.5 : 1)
                        )
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
                    }
                }
            }
            .padding(24)
        }
        .sheet(item: $editingScene) { scene in
            SceneEditorSheet(scene: scene, manager: manager)
        }
        .sheet(isPresented: $isCreatingNewScene) {
            SceneEditorSheet(scene: nil, manager: manager)
        }
    }

    private func triggerScene(_ scene: SmartScene) {
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
    }

    @ViewBuilder
    private func sceneTargetBadges(for scene: SmartScene) -> some View {
        let lower = scene.name.lowercased()
        let hasLights = manager.devices.contains { $0.type == .light }
        let hasFans = manager.devices.contains { $0.type == .fan }
        let hasPlugs = manager.devices.contains { $0.type == .plug }
        let hasACs = manager.devices.contains { $0.type == .airConditioner }

        HStack(spacing: 5) {
            if hasLights {
                deviceBadge(icon: "lightbulb.fill", label: "Lights")
            }
            if hasFans {
                deviceBadge(icon: "fanblades.fill", label: "Fans")
            }
            if hasPlugs && (lower.contains("all") || lower.contains("night") || lower.contains("focus")) {
                deviceBadge(icon: "poweroutlet.type.g.fill", label: "Plugs")
            }
            if hasACs {
                deviceBadge(icon: "snowflake", label: "AC")
            }
        }
    }

    private func deviceBadge(icon: String, label: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(label)
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.12))
        .foregroundColor(.secondary)
        .clipShape(Capsule())
    }
}

struct SceneEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    var scene: SmartScene?
    @Bindable var manager: DeviceManager

    @State private var name: String = ""
    @State private var subtitle: String = ""
    @State private var selectedIcon: String = "sparkles"
    @State private var selectedColor: String = "blue"

    private let availableIcons = [
        "moon.stars.fill", "film.fill", "briefcase.fill", "cup.and.saucer.fill",
        "power", "sun.max.fill", "sparkles", "house.fill", "bed.double.fill",
        "flame.fill", "heart.fill", "music.note", "theatermasks.fill", "book.fill"
    ]

    private let availableColors = [
        "indigo", "purple", "blue", "cyan", "green", "orange", "red", "yellow", "pink"
    ]

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text(scene == nil ? "New Scene" : "Edit Scene")
                    .font(.title3.bold())
                Spacer()
                Button("Done") {
                    save()
                    dismiss()
                }
                .font(.system(size: 13, weight: .semibold))
                .keyboardShortcut(.defaultAction)
            }

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    TextField("Scene Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Description")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    TextField("What does this scene do?", text: $subtitle)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Icon")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(availableIcons, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.system(size: 16))
                                        .frame(width: 36, height: 36)
                                        .background(selectedIcon == icon ? Color.accentColor : Color.secondary.opacity(0.12))
                                        .foregroundColor(selectedIcon == icon ? .white : .primary)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Accent Color")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    HStack(spacing: 10) {
                        ForEach(availableColors, id: \.self) { colorName in
                            Button {
                                selectedColor = colorName
                            } label: {
                                Circle()
                                    .fill(colorFor(colorName))
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: selectedColor == colorName ? 2.5 : 0)
                                    )
                                    .shadow(color: colorFor(colorName).opacity(0.4), radius: 3)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Spacer()

            if let existing = scene {
                HStack {
                    Button(role: .destructive) {
                        manager.deleteScene(existing)
                        dismiss()
                    } label: {
                        Text("Delete Scene")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(24)
        .frame(width: 420, height: 420)
        .onAppear {
            if let sc = scene {
                name = sc.name
                subtitle = sc.subtitle
                selectedIcon = sc.icon
                selectedColor = sc.accentColorName
            } else {
                name = ""
                subtitle = ""
                selectedIcon = "sparkles"
                selectedColor = "blue"
            }
        }
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }

        if var existing = scene {
            existing.name = cleanName
            existing.subtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.icon = selectedIcon
            existing.accentColorName = selectedColor
            manager.updateScene(existing)
        } else {
            let newScene = SmartScene(
                name: cleanName,
                subtitle: subtitle.trimmingCharacters(in: .whitespacesAndNewlines),
                icon: selectedIcon,
                accentColorName: selectedColor,
                commands: [],
                isCustom: true
            )
            manager.addScene(newScene)
        }
    }

    private func colorFor(_ name: String) -> Color {
        switch name.lowercased() {
        case "indigo": return .indigo
        case "purple": return .purple
        case "red": return Color(red: 1.0, green: 0.35, blue: 0.35)
        case "blue": return .blue
        case "orange": return .orange
        case "green": return .green
        case "yellow": return .yellow
        case "pink": return .pink
        case "cyan": return .cyan
        default: return .blue
        }
    }
}
