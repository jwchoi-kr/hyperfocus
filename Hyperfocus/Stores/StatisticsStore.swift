import Foundation
import os.log

private let logger = Logger(subsystem: "com.hyperfocus", category: "StatisticsStore")

@Observable
final class StatisticsStore {
    private(set) var pastDays: [Day]

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

    func aggregatedSessions(of day: Day) -> [AggregatedSession] {
        aggregateSessions(day.sessions)
    }

    func aggregatedSessionsIncluding(day: Day, active: Session?) -> [AggregatedSession] {
        var all = day.sessions
        if let active = active, active.duration > 0 {
            var copy = active
            copy.name = normalizedSessionName(active.name)
            all.append(copy)
        }
        return aggregateSessions(all)
    }
}
