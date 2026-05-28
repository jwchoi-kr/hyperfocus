import AppKit
import os.log

private let logger = Logger(subsystem: "com.hyperfocus", category: "FocusBlocker")

final class FocusBlocker {
    private var blocklist: FocusBlocklist = FocusBlocklist()
    private(set) var isActive: Bool = false

    private var appLaunchObserver: NSObjectProtocol?
    private var tabPollingTimer: Timer?

    func activate(blocklist: FocusBlocklist) {
        self.blocklist = blocklist
        guard !isActive else { return }
        isActive = true
        startAppLaunchMonitoring()
        startTabPolling()
        logger.info("FocusBlocker activated — apps: \(blocklist.blockedApps.count), sites: \(blocklist.blockedSites.count)")
    }

    func deactivate() {
        guard isActive else { return }
        isActive = false
        stopAppLaunchMonitoring()
        stopTabPolling()
        logger.info("FocusBlocker deactivated")
    }

    func updateBlocklist(_ blocklist: FocusBlocklist) {
        self.blocklist = blocklist
    }

    // MARK: - App blocking

    private func startAppLaunchMonitoring() {
        appLaunchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }
            self.terminateIfBlocked(app)
        }

        for app in NSWorkspace.shared.runningApplications {
            terminateIfBlocked(app)
        }
    }

    private func stopAppLaunchMonitoring() {
        if let observer = appLaunchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            appLaunchObserver = nil
        }
    }

    private func terminateIfBlocked(_ app: NSRunningApplication) {
        guard let bundle = app.bundleIdentifier,
              blocklist.blockedApps.contains(where: { $0.bundleIdentifier == bundle })
        else { return }
        app.forceTerminate()
        logger.info("Force-terminated blocked app: \(bundle)")
    }

    // MARK: - Tab blocking

    private func startTabPolling() {
        guard !blocklist.blockedSites.isEmpty else { return }
        scheduleTabPolling()
    }

    private func scheduleTabPolling() {
        tabPollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.closeBlockedChromeTabs()
        }
    }

    private func stopTabPolling() {
        tabPollingTimer?.invalidate()
        tabPollingTimer = nil
    }

    private func closeBlockedChromeTabs() {
        let chromeRunning = NSWorkspace.shared.runningApplications
            .contains { $0.bundleIdentifier == "com.google.Chrome" }
        guard chromeRunning, !blocklist.blockedSites.isEmpty else { return }

        let domainsLiteral = blocklist.blockedSites
            .map { "\"\($0.domain)\"" }
            .joined(separator: ", ")

        // Iterates tabs in reverse so deletions don't shift earlier indices.
        let script = """
        set blockedDomains to {\(domainsLiteral)}
        tell application "Google Chrome"
            repeat with w in windows
                set tabCount to count of tabs of w
                repeat with i from tabCount to 1 by -1
                    set t to tab i of w
                    set tabURL to URL of t
                    repeat with d in blockedDomains
                        if tabURL contains d then
                            delete t
                            exit repeat
                        end if
                    end repeat
                end repeat
            end repeat
        end tell
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            logger.error("osascript launch failed: \(error.localizedDescription)")
        }
    }
}
