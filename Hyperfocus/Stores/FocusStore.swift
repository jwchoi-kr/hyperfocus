import Foundation
import os.log

private let logger = Logger(subsystem: "com.hyperfocus", category: "FocusStore")

@Observable
final class FocusStore {
    private(set) var blockedApps: [BlockedApp]
    private(set) var blockedSites: [BlockedSite]

    var onStateChanged: (() -> Void)?

    init(blocklist: FocusBlocklist = FocusBlocklist()) {
        self.blockedApps = blocklist.blockedApps
        self.blockedSites = blocklist.blockedSites
    }

    func addApp(_ app: BlockedApp) {
        blockedApps.append(app)
        logger.info("Blocked app added: \(app.bundleIdentifier)")
        onStateChanged?()
    }

    func removeApp(id: UUID) {
        blockedApps.removeAll { $0.id == id }
        logger.info("Blocked app removed: \(id)")
        onStateChanged?()
    }

    func addSite(_ site: BlockedSite) {
        blockedSites.append(site)
        logger.info("Blocked site added: \(site.domain)")
        onStateChanged?()
    }

    func removeSite(id: UUID) {
        blockedSites.removeAll { $0.id == id }
        logger.info("Blocked site removed: \(id)")
        onStateChanged?()
    }
}
