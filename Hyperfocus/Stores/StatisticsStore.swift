import Foundation
import os.log

private let logger = Logger(subsystem: "com.hyperfocus", category: "StatisticsStore")

@Observable
final class StatisticsStore {
    private(set) var pastCycles: [Cycle]

    init(pastCycles: [Cycle] = []) {
        self.pastCycles = pastCycles
    }

    func appendClosedCycle(_ cycle: Cycle) {
        guard !cycle.isEmpty else {
            logger.info("Skipping empty cycle")
            return
        }
        pastCycles.insert(cycle, at: 0)
        logger.info("Past cycle added, total=\(self.pastCycles.count)")
    }

    /// Average duration of the most recent `count` past cycles (excluding current).
    /// Returns nil when there are no past cycles.
    func recentAverage(count: Int = 7) -> (average: TimeInterval, sampleSize: Int)? {
        guard !pastCycles.isEmpty else { return nil }
        let sample = Array(pastCycles.prefix(count))
        let total = sample.reduce(0.0) { $0 + $1.totalDuration }
        return (total / Double(sample.count), sample.count)
    }

    func aggregatedSessions(of cycle: Cycle) -> [AggregatedSession] {
        aggregateSessions(cycle.sessions)
    }

    func aggregatedSessionsIncluding(cycle: Cycle, active: Session?) -> [AggregatedSession] {
        var all = cycle.sessions
        if let active = active, active.duration > 0 {
            var copy = active
            copy.name = normalizedSessionName(active.name)
            all.append(copy)
        }
        return aggregateSessions(all)
    }
}
