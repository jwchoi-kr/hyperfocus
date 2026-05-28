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
        let before = blockedApps.count
        blockedApps.removeAll { $0.id == id }
        guard blockedApps.count != before else { return }
        logger.info("Blocked app removed: \(id)")
        onStateChanged?()
    }

    func addSite(_ site: BlockedSite) {
        blockedSites.append(site)
        logger.info("Blocked site added: \(site.domain)")
        onStateChanged?()
    }

    func removeSite(id: UUID) {
        let before = blockedSites.count
        blockedSites.removeAll { $0.id == id }
        guard blockedSites.count != before else { return }
        logger.info("Blocked site removed: \(id)")
        onStateChanged?()
    }
}
