import XCTest
@testable import Hyperfocus

final class AverageCalculationTests: XCTestCase {

    private func makeDay(duration: TimeInterval) -> Day {
        var d = Day()
        d.sessions = [Session(name: "test", duration: duration)]
        d.endedAt = Date()
        return d
    }

    func test_recentAverage_noPastDays_returnsNil() {
        let store = StatisticsStore(pastDays: [])
        XCTAssertNil(store.recentAverage())
    }

    func test_recentAverage_threeDays_correctAverage() {
        let days = [
            makeDay(duration: 3600),
            makeDay(duration: 7200),
            makeDay(duration: 5400),
        ]
        let store = StatisticsStore(pastDays: days)
        let result = store.recentAverage()
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.average, (3600 + 7200 + 5400) / 3, accuracy: 0.001)
        XCTAssertEqual(result!.sampleSize, 3)
    }

    func test_recentAverage_exactlySevenDays() {
        let durations: [TimeInterval] = [1000, 2000, 3000, 4000, 5000, 6000, 7000]
        let days = durations.map { makeDay(duration: $0) }
        let store = StatisticsStore(pastDays: days)
        let result = store.recentAverage()
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.sampleSize, 7)
        let expected = durations.reduce(0, +) / 7
        XCTAssertEqual(result!.average, expected, accuracy: 0.001)
    }

    func test_recentAverage_moreThanSevenDays_onlyUsesFirst7() {
        let durations: [TimeInterval] = [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000]
        let days = durations.map { makeDay(duration: $0) }
        let store = StatisticsStore(pastDays: days)
        let result = store.recentAverage()
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.sampleSize, 7)
        // Should use first 7 (most recent)
        let expected = durations.prefix(7).reduce(0, +) / 7
        XCTAssertEqual(result!.average, expected, accuracy: 0.001)
    }

    func test_appendClosedDay_emptySkipped() {
        let store = StatisticsStore()
        let emptyDay = Day()
        store.appendClosedDay(emptyDay)
        XCTAssertTrue(store.pastDays.isEmpty)
    }

    func test_appendClosedDay_nonEmptyAdded() {
        let store = StatisticsStore()
        let day = makeDay(duration: 100)
        store.appendClosedDay(day)
        XCTAssertEqual(store.pastDays.count, 1)
    }

    func test_appendClosedDay_mostRecentFirst() {
        let store = StatisticsStore()
        let first = makeDay(duration: 100)
        let second = makeDay(duration: 200)
        store.appendClosedDay(first)
        store.appendClosedDay(second)
        // Second appended is at index 0 (inserted at front)
        XCTAssertEqual(store.pastDays[0].sessions[0].duration, 200)
        XCTAssertEqual(store.pastDays[1].sessions[0].duration, 100)
    }
}
