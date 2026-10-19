import SwiftUI
import AppKit

enum AppLogoImage {
    static var rawImage: NSImage? {
        #if SWIFT_PACKAGE
        if let url = Bundle.module.url(forResource: "app-logo", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        #endif
        if let url = Bundle.main.url(forResource: "app-logo", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        let resURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/app-logo.png")
        if let img = NSImage(contentsOf: resURL) {
            return img
        }
        let devURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Control/Assets/app-logo.png")
        if let img = NSImage(contentsOf: devURL) {
            return img
        }
        return nil
    }

    static var menuBarMonochromeC: NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let baseFont = NSFont.systemFont(ofSize: 14.0, weight: .heavy)
            let font: NSFont
            if let desc = baseFont.fontDescriptor.withDesign(.rounded),
               let rounded = NSFont(descriptor: desc, size: 14.0) {
                font = rounded
            } else {
                font = baseFont
            }
            let str = "C" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.black
            ]
            let sSize = str.size(withAttributes: attrs)
            let drawRect = NSRect(
                x: (rect.width - sSize.width) / 2.0,
                y: (rect.height - sSize.height) / 2.0 - 0.5,
                width: sSize.width,
                height: sSize.height
            )
            str.draw(in: drawRect, withAttributes: attrs)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Control"
        return image
    }

    static var menuBarIcon: NSImage? {
        guard let original = rawImage else { return nil }
        let size = NSSize(width: 18, height: 18)
        let resized = NSImage(size: size)
        resized.lockFocus()
        original.draw(in: NSRect(origin: .zero, size: size),
                      from: NSRect(origin: .zero, size: original.size),
                      operation: .copy,
                      fraction: 1.0)
        resized.unlockFocus()
        resized.isTemplate = false
        return resized
    }
}

struct AppLogoView: View {
    var size: CGFloat = 36
    var cornerRadius: CGFloat = 0

    var body: some View {
        if let nsImage = AppLogoImage.rawImage {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "house.fill")
                .font(.system(size: size * 0.7, weight: .bold))
                .foregroundColor(.blue)
        }
    }
}
