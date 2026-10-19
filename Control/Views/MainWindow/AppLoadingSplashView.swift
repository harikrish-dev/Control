import SwiftUI
import AppKit
import AVKit
import AVFoundation

struct AppLoadingSplashView: View {
    var onFinished: () -> Void

    @State private var player: AVPlayer? = nil
    @State private var isFinished: Bool = false

    private var videoURL: URL? {
        // 1. SPM module bundle (Assets processed by Swift Package Manager)
        if let url = Bundle.module.url(forResource: "splash", withExtension: "mp4") {
            return url
        }
        // 2. App Bundle Resources (Control.app/Contents/Resources/splash.mp4)
        if let url = Bundle.main.url(forResource: "splash", withExtension: "mp4") {
            return url
        }
        let resURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/splash.mp4")
        if FileManager.default.fileExists(atPath: resURL.path) {
            return resURL
        }
        // 3. Project Assets directory
        let assetsURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Control/Assets/splash.mp4")
        if FileManager.default.fileExists(atPath: assetsURL.path) {
            return assetsURL
        }
        return nil
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if let player = player {
                NativeVideoPlayer(player: player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            finish()
        }
        .onAppear {
            startPlayback()
        }
    }

    private func startPlayback() {
        guard let url = videoURL else {
            // Fallback timeout if video is missing
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                finish()
            }
            return
        }

        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.isMuted = true
        newPlayer.volume = 0.0
        newPlayer.actionAtItemEnd = .pause
        self.player = newPlayer

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            finish()
        }

        newPlayer.play()

        // Fallback timer (video is 2.56s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) {
            finish()
        }
    }

    private func finish() {
        guard !isFinished else { return }
        isFinished = true
        player?.pause()
        onFinished()
    }
}

struct NativeVideoPlayer: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.showsFullScreenToggleButton = false
        view.showsSharingServiceButton = false
        view.videoGravity = .resizeAspect
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}
