import Foundation
import os.log

private let logger = Logger(subsystem: "com.hyperfocus", category: "MacOSFocusBridge")

final class MacOSFocusBridge {
    private static let activateShortcut = "Focus On"
    private static let deactivateShortcut = "Focus Off"

    func activate() {
        run(shortcut: MacOSFocusBridge.activateShortcut)
    }

    func deactivate() {
        run(shortcut: MacOSFocusBridge.deactivateShortcut)
    }

    private func run(shortcut: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["run", shortcut]

            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus != 0 {
                    logger.warning("Shortcut '\(shortcut)' exited with status \(process.terminationStatus) — check Shortcuts app")
                } else {
                    logger.info("Shortcut '\(shortcut)' executed successfully")
                }
            } catch {
                logger.warning("Failed to run shortcut '\(shortcut)': \(error.localizedDescription)")
            }
        }
    }
}
