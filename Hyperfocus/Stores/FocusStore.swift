import Foundation
import os.log

private let logger = Logger(subsystem: "com.hyperfocus", category: "FocusStore")

@Observable
final class FocusStore {
    private(set) var blockedApps: [BlockedApp]
    private(set) var blockedSites: [BlockedSite]
    private(set) var isMacOSFocusEnabled: Bool

    var onStateChanged: (() -> Void)?

    var currentBlocklist: FocusBlocklist {
        FocusBlocklist(blockedApps: blockedApps, blockedSites: blockedSites, isMacOSFocusEnabled: isMacOSFocusEnabled)
    }

    init(blocklist: FocusBlocklist = FocusBlocklist()) {
        self.blockedApps = blocklist.blockedApps
        self.blockedSites = blocklist.blockedSites
        self.isMacOSFocusEnabled = blocklist.isMacOSFocusEnabled
    }

    func addApp(_ app: BlockedApp) {
        blockedApps.append(app)
        logger.info("Blocked app added: \(app.bundleIdentifier)")
        onStateChanged?()
    }

    func removeApp(id: UUID) {
        guard let idx = blockedApps.firstIndex(where: { $0.id == id }) else { return }
        blockedApps.remove(at: idx)
        logger.info("Blocked app removed: \(id)")
        onStateChanged?()
    }

    func addSite(_ site: BlockedSite) {
        blockedSites.append(site)
        logger.info("Blocked site added: \(site.domain)")
        onStateChanged?()
    }

    func removeSite(id: UUID) {
        guard let idx = blockedSites.firstIndex(where: { $0.id == id }) else { return }
        blockedSites.remove(at: idx)
        logger.info("Blocked site removed: \(id)")
        onStateChanged?()
    }

    func setMacOSFocusEnabled(_ enabled: Bool) {
        guard isMacOSFocusEnabled != enabled else { return }
        isMacOSFocusEnabled = enabled
        logger.info("macOS Focus integration \(enabled ? "enabled" : "disabled")")
        onStateChanged?()
    }
}
