import Foundation

struct BlockedApp: Codable, Identifiable, Equatable {
    let id: UUID
    var bundleIdentifier: String
    var displayName: String
}

struct BlockedSite: Codable, Identifiable, Equatable {
    let id: UUID
    var domain: String
}

struct FocusBlocklist: Codable, Equatable {
    var blockedApps: [BlockedApp]
    var blockedSites: [BlockedSite]
    var isMacOSFocusEnabled: Bool

    init(blockedApps: [BlockedApp] = [], blockedSites: [BlockedSite] = [], isMacOSFocusEnabled: Bool = false) {
        self.blockedApps = blockedApps
        self.blockedSites = blockedSites
        self.isMacOSFocusEnabled = isMacOSFocusEnabled
    }
}
