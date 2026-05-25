import Foundation

struct AggregatedSession: Identifiable {
    let id = UUID()
    let name: String
    let totalDuration: TimeInterval
}

func aggregateSessions(_ sessions: [Session]) -> [AggregatedSession] {
    var totals: [String: TimeInterval] = [:]
    for session in sessions {
        let key = normalizedSessionName(session.name)
        totals[key, default: 0] += session.duration
    }
    return totals
        .map { AggregatedSession(name: $0.key, totalDuration: $0.value) }
        .sorted { $0.totalDuration > $1.totalDuration }
}

func normalizedSessionName(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? "(Untitled)" : trimmed
}
