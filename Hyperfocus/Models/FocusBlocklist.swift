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

    init(blockedApps: [BlockedApp] = [], blockedSites: [BlockedSite] = []) {
        self.blockedApps = blockedApps
        self.blockedSites = blockedSites
    }
}
