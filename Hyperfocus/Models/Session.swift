import Foundation

struct Session: Codable, Identifiable {
    let id: UUID
    var name: String
    var duration: TimeInterval
    let startedAt: Date

    init(id: UUID = UUID(), name: String = "", duration: TimeInterval = 0, startedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.duration = duration
        self.startedAt = startedAt
    }
}
