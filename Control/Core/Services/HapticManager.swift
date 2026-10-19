import AppKit
import AudioToolbox
import Observation

@Observable
final class HapticManager {
    static let shared = HapticManager()

    var isMuted: Bool {
        didSet {
            UserDefaults.standard.set(isMuted, forKey: "isHapticSoundMuted")
        }
    }

    @ObservationIgnored
    private let clickPool: [NSSound]
    @ObservationIgnored
    private var clickIndex = 0

    @ObservationIgnored
    private let snapPool: [NSSound]
    @ObservationIgnored
    private var snapIndex = 0

    @ObservationIgnored
    private let tickPool: [NSSound]
    @ObservationIgnored
    private var tickIndex = 0

    @ObservationIgnored
    private var clickSoundID: SystemSoundID = 0
    @ObservationIgnored
    private var snapSoundID: SystemSoundID = 0
    @ObservationIgnored
    private var tickSoundID: SystemSoundID = 0

    @ObservationIgnored
    private let lock = NSLock()

    private init() {
        self.isMuted = UserDefaults.standard.bool(forKey: "isHapticSoundMuted")

        let mouseClickPath = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/accessibility/Mouse Keys ON.aif"
        let tickPath = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/accessibility/Slow Keys, 1st Key Pressed.aif"
        let snapPath = "/System/Library/Sounds/Tink.aiff"

        // AudioServices System Sound IDs
        if FileManager.default.fileExists(atPath: mouseClickPath) {
            AudioServicesCreateSystemSoundID(URL(fileURLWithPath: mouseClickPath) as CFURL, &clickSoundID)
        }
        if FileManager.default.fileExists(atPath: snapPath) {
            AudioServicesCreateSystemSoundID(URL(fileURLWithPath: snapPath) as CFURL, &snapSoundID)
        }
        if FileManager.default.fileExists(atPath: tickPath) {
            AudioServicesCreateSystemSoundID(URL(fileURLWithPath: tickPath) as CFURL, &tickSoundID)
        }

        // 1. Mechanical click pool (NSSound)
        var clicks: [NSSound] = []
        for _ in 0..<6 {
            if let sound = NSSound(contentsOfFile: mouseClickPath, byReference: true) {
                sound.volume = 1.0
                clicks.append(sound)
            } else if let sound = NSSound(named: "Pop") {
                sound.volume = 0.9
                clicks.append(sound)
            }
        }
        self.clickPool = clicks

        // 2. Snap / Detent preset selection pool (NSSound)
        var snaps: [NSSound] = []
        for _ in 0..<6 {
            if let sound = NSSound(contentsOfFile: snapPath, byReference: true) ?? NSSound(named: "Tink") {
                sound.volume = 0.9
                snaps.append(sound)
            }
        }
        self.snapPool = snaps

        // 3. Tactile tick pool for slider drags (NSSound)
        var ticks: [NSSound] = []
        for _ in 0..<8 {
            if let sound = NSSound(contentsOfFile: tickPath, byReference: true) {
                sound.volume = 0.8
                ticks.append(sound)
            } else if let sound = NSSound(named: "Tink") {
                sound.volume = 0.6
                ticks.append(sound)
            }
        }
        self.tickPool = ticks
    }

    func toggleMute() {
        isMuted.toggle()
        if !isMuted {
            playClick()
        }
    }

    func playClick() {
        // Physical Force Touch trackpad haptic
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)

        guard !isMuted else { return }

        // Native System Sound playback
        if clickSoundID != 0 {
            AudioServicesPlaySystemSound(clickSoundID)
        }

        // Direct NSSound playback
        lock.lock()
        defer { lock.unlock() }
        guard !clickPool.isEmpty else { return }
        let sound = clickPool[clickIndex % clickPool.count]
        clickIndex += 1
        sound.stop()
        sound.currentTime = 0
        sound.play()
    }

    func playSnap() {
        // Physical Force Touch trackpad detent
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)

        guard !isMuted else { return }

        // Native System Sound playback
        if snapSoundID != 0 {
            AudioServicesPlaySystemSound(snapSoundID)
        }

        // Direct NSSound playback
        lock.lock()
        defer { lock.unlock() }
        guard !snapPool.isEmpty else { return }
        let sound = snapPool[snapIndex % snapPool.count]
        snapIndex += 1
        sound.stop()
        sound.currentTime = 0
        sound.play()
    }

    func playLevelChange() {
        // Physical Force Touch trackpad slider tick
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)

        guard !isMuted else { return }

        // Native System Sound playback
        if tickSoundID != 0 {
            AudioServicesPlaySystemSound(tickSoundID)
        }

        // Direct NSSound playback
        lock.lock()
        defer { lock.unlock() }
        guard !tickPool.isEmpty else { return }
        let sound = tickPool[tickIndex % tickPool.count]
        tickIndex += 1
        sound.stop()
        sound.currentTime = 0
        sound.play()
    }
}

enum HapticFeedback {
    static var isMuted: Bool {
        get { HapticManager.shared.isMuted }
        set { HapticManager.shared.isMuted = newValue }
    }

    static func toggleMute() {
        HapticManager.shared.toggleMute()
    }

    static func click() {
        HapticManager.shared.playClick()
    }

    static func snap() {
        HapticManager.shared.playSnap()
    }

    static func levelChange() {
        HapticManager.shared.playLevelChange()
    }
}
