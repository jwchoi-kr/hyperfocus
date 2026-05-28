// Hyperfocus/Models/FocusBlocklist.swift
import Foundation

struct BlockedApp: Codable, Identifiable, Equatable {
    var id: UUID
    var bundleIdentifier: String  // "com.kakao.KakaoTalk"
    var displayName: String       // "카카오톡"
}

struct BlockedSite: Codable, Identifiable, Equatable {
    var id: UUID
    var domain: String            // "linkedin.com"
}

struct FocusBlocklist: Codable, Equatable {
    var blockedApps: [BlockedApp]
    var blockedSites: [BlockedSite]

    init(blockedApps: [BlockedApp] = [], blockedSites: [BlockedSite] = []) {
        self.blockedApps = blockedApps
        self.blockedSites = blockedSites
    }
}
