import Foundation
import os.log

private let logger = Logger(subsystem: "com.hyperfocus", category: "StatisticsStore")

@Observable
final class StatisticsStore {
    private(set) var pastDays: [Day]

    var onStateChanged: (() -> Void)?

    init(pastDays: [Day] = []) {
        self.pastDays = pastDays
    }

    func appendClosedDay(_ day: Day) {
        guard !day.isEmpty else {
            logger.info("Skipping empty day")
            return
        }
        pastDays.insert(day, at: 0)
        logger.info("Past day added, total=\(self.pastDays.count)")
    }

    /// Average duration of the most recent `count` past days (excluding current).
    /// Returns nil when there are no past days.
    func recentAverage(count: Int = 7) -> (average: TimeInterval, sampleSize: Int)? {
        guard !pastDays.isEmpty else { return nil }
        let sample = Array(pastDays.prefix(count))
        let total = sample.reduce(0.0) { $0 + $1.totalDuration }
        return (total / Double(sample.count), sample.count)
    }

    func sessions(of day: Day) -> [Session] {
        day.sessions.sorted { $0.startedAt < $1.startedAt }
    }

    func renameSession(in day: Day, sessionID: UUID, to newTitle: String) {
        guard let dayIdx = pastDays.firstIndex(where: { $0.id == day.id }) else { return }
        guard let sessionIdx = pastDays[dayIdx].sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        let normalized = normalizedSessionName(newTitle)
        pastDays[dayIdx].sessions[sessionIdx].name = normalized
        logger.info("Renamed session \(sessionID) → '\(normalized)' in day \(day.id)")
        onStateChanged?()
    }

    func deleteSession(in day: Day, sessionID: UUID) {
        guard let dayIdx = pastDays.firstIndex(where: { $0.id == day.id }) else { return }
        pastDays[dayIdx].sessions.removeAll { $0.id == sessionID }
        logger.info("Deleted session \(sessionID) from day \(day.id)")
        if pastDays[dayIdx].isEmpty {
            pastDays.remove(at: dayIdx)
            logger.info("Day removed after becoming empty")
        }
        onStateChanged?()
    }
}
