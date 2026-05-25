import SwiftUI
import AppKit

struct MenuBarLabel: View {
    @Environment(TimerStore.self) private var timerStore

    var body: some View {
        Image(nsImage: menuBarImage)
    }

    private var menuBarImage: NSImage {
        let timerText = formatHHMMSS(timerStore.currentSessionDuration)
        let rawName = timerStore.activeSession?.name ?? ""
        let title = rawName.trimmingCharacters(in: .whitespaces).isEmpty ? "(Untitled)" : rawName
        return twoLineImage(title: title, timer: timerText)
    }

    private func twoLineImage(title: String, timer: String) -> NSImage {
        let titleFont = NSFont.systemFont(ofSize: 9, weight: .regular)
        let timerFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        let attrs: (NSFont) -> [NSAttributedString.Key: Any] = { [.font: $0] }

        let timerAttr = NSAttributedString(string: timer, attributes: attrs(timerFont))
        let timerSize = timerAttr.size()

        // Title is capped at the timer width so the item never grows wider than HH:MM:SS
        let titleAttr = truncatedAttributedString(title, font: titleFont, maxWidth: timerSize.width)
        let titleSize = titleAttr.size()

        let w: CGFloat = timerSize.width + 6
        // Two rows: title on top, timer below, with a small gap
        let h: CGFloat = titleSize.height + timerSize.height + 2

        let image = NSImage(size: NSSize(width: w, height: h), flipped: false) { _ in
            // Timer on bottom
            timerAttr.draw(at: NSPoint(x: (w - timerSize.width) / 2, y: 0))
            // Title on top
            titleAttr.draw(at: NSPoint(x: (w - titleSize.width) / 2, y: timerSize.height + 2))
            return true
        }
        image.isTemplate = true
        return image
    }

    private func truncatedAttributedString(_ text: String, font: NSFont, maxWidth: CGFloat) -> NSAttributedString {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        var truncated = text
        var attrStr = NSAttributedString(string: truncated, attributes: attrs)
        while attrStr.size().width > maxWidth && truncated.count > 1 {
            truncated = String(truncated.dropLast())
            attrStr = NSAttributedString(string: truncated + "…", attributes: attrs)
        }
        if text != truncated {
            return NSAttributedString(string: truncated + "…", attributes: attrs)
        }
        return NSAttributedString(string: text, attributes: attrs)
    }
}
