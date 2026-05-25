import XCTest
@testable import Hyperfocus

final class SessionAggregationTests: XCTestCase {

    func test_emptySessions_returnsEmpty() {
        XCTAssertTrue(aggregateSessions([]).isEmpty)
    }

    func test_singleSession_returnsSelf() {
        let s = Session(name: "작업", duration: 100)
        let result = aggregateSessions([s])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "작업")
        XCTAssertEqual(result[0].totalDuration, 100)
    }

    func test_sameNameSessions_mergedIntoOne() {
        let s1 = Session(name: "React", duration: 100)
        let s2 = Session(name: "React", duration: 200)
        let result = aggregateSessions([s1, s2])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].totalDuration, 300)
    }

    func test_differentCaseName_notMerged() {
        // SPEC §6.3: 대소문자 구분
        let s1 = Session(name: "React", duration: 100)
        let s2 = Session(name: "react", duration: 200)
        let result = aggregateSessions([s1, s2])
        XCTAssertEqual(result.count, 2)
    }

    func test_emptyName_normalizedToUnnamed() {
        let s = Session(name: "", duration: 50)
        let result = aggregateSessions([s])
        XCTAssertEqual(result[0].name, "(이름 없음)")
    }

    func test_whitespaceOnlyName_normalizedToUnnamed() {
        let s = Session(name: "   ", duration: 50)
        let result = aggregateSessions([s])
        XCTAssertEqual(result[0].name, "(이름 없음)")
    }

    func test_multipleUnnamedSessions_mergedIntoOne() {
        let s1 = Session(name: "", duration: 30)
        let s2 = Session(name: "   ", duration: 20)
        let result = aggregateSessions([s1, s2])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "(이름 없음)")
        XCTAssertEqual(result[0].totalDuration, 50)
    }

    func test_leadingTrailingWhitespaceTrimmed() {
        let s1 = Session(name: " React ", duration: 100)
        let s2 = Session(name: "React", duration: 50)
        let result = aggregateSessions([s1, s2])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].totalDuration, 150)
    }

    func test_sortedByDurationDescending() {
        let sessions = [
            Session(name: "A", duration: 50),
            Session(name: "B", duration: 200),
            Session(name: "C", duration: 100),
        ]
        let result = aggregateSessions(sessions)
        XCTAssertEqual(result.map(\.name), ["B", "C", "A"])
    }
}
