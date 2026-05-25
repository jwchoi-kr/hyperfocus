import Foundation

struct Day: Codable, Identifiable {
    let id: UUID
    let startedAt: Date
    var endedAt: Date?
    var sessions: [Session]

    init(id: UUID = UUID(), startedAt: Date = Date(), endedAt: Date? = nil, sessions: [Session] = []) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.sessions = sessions
    }

    var isEmpty: Bool { sessions.isEmpty }

    var totalDuration: TimeInterval {
        sessions.reduce(0) { $0 + $1.duration }
    }
}
