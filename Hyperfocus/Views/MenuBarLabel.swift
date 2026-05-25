import SwiftUI
import AppKit

struct MenuBarLabel: View {
    @Environment(TimerStore.self) private var timerStore

    var body: some View {
        Image(nsImage: timerImage)
    }

    private var timerImage: NSImage {
        let text = formatHHMMSS(timerStore.activeSession != nil ? timerStore.currentSessionDuration : 0)
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let textSize = attrStr.size()

        let imageWidth: CGFloat = 62
        let imageHeight: CGFloat = 16

        let image = NSImage(size: NSSize(width: imageWidth, height: imageHeight), flipped: false) { _ in
            let x = (imageWidth - textSize.width) / 2
            let y = (imageHeight - textSize.height) / 2
            attrStr.draw(at: NSPoint(x: x, y: y))
            return true
        }
        // Template images are automatically colored for light/dark mode by the system
        image.isTemplate = true
        return image
    }
}
