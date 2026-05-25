import XCTest
@testable import Hyperfocus

final class AverageCalculationTests: XCTestCase {

    private func makeCycle(duration: TimeInterval) -> Cycle {
        var c = Cycle()
        c.sessions = [Session(name: "test", duration: duration)]
        c.endedAt = Date()
        return c
    }

    func test_recentAverage_noPastCycles_returnsNil() {
        let store = StatisticsStore(pastCycles: [])
        XCTAssertNil(store.recentAverage())
    }

    func test_recentAverage_threeCycles_correctAverage() {
        let cycles = [
            makeCycle(duration: 3600),
            makeCycle(duration: 7200),
            makeCycle(duration: 5400),
        ]
        let store = StatisticsStore(pastCycles: cycles)
        let result = store.recentAverage()
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.average, (3600 + 7200 + 5400) / 3, accuracy: 0.001)
        XCTAssertEqual(result!.sampleSize, 3)
    }

    func test_recentAverage_exactlySevenCycles() {
        let durations: [TimeInterval] = [1000, 2000, 3000, 4000, 5000, 6000, 7000]
        let cycles = durations.map { makeCycle(duration: $0) }
        let store = StatisticsStore(pastCycles: cycles)
        let result = store.recentAverage()
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.sampleSize, 7)
        let expected = durations.reduce(0, +) / 7
        XCTAssertEqual(result!.average, expected, accuracy: 0.001)
    }

    func test_recentAverage_moreThanSevenCycles_onlyUsesFirst7() {
        let durations: [TimeInterval] = [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000]
        let cycles = durations.map { makeCycle(duration: $0) }
        let store = StatisticsStore(pastCycles: cycles)
        let result = store.recentAverage()
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.sampleSize, 7)
        // Should use first 7 (most recent)
        let expected = durations.prefix(7).reduce(0, +) / 7
        XCTAssertEqual(result!.average, expected, accuracy: 0.001)
    }

    func test_appendClosedCycle_emptySkipped() {
        let store = StatisticsStore()
        let emptyCycle = Cycle()
        store.appendClosedCycle(emptyCycle)
        XCTAssertTrue(store.pastCycles.isEmpty)
    }

    func test_appendClosedCycle_nonEmptyAdded() {
        let store = StatisticsStore()
        let cycle = makeCycle(duration: 100)
        store.appendClosedCycle(cycle)
        XCTAssertEqual(store.pastCycles.count, 1)
    }

    func test_appendClosedCycle_mostRecentFirst() {
        let store = StatisticsStore()
        let first = makeCycle(duration: 100)
        let second = makeCycle(duration: 200)
        store.appendClosedCycle(first)
        store.appendClosedCycle(second)
        // Second appended is at index 0 (inserted at front)
        XCTAssertEqual(store.pastCycles[0].sessions[0].duration, 200)
        XCTAssertEqual(store.pastCycles[1].sessions[0].duration, 100)
    }
}
