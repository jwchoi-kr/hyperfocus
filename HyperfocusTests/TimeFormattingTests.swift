import XCTest
@testable import Hyperfocus

final class TimeFormattingTests: XCTestCase {

    func test_formatHHMMSS_zero() {
        XCTAssertEqual(formatHHMMSS(0), "00:00:00")
    }

    func test_formatHHMMSS_59seconds() {
        XCTAssertEqual(formatHHMMSS(59), "00:00:59")
    }

    func test_formatHHMMSS_oneMinute() {
        XCTAssertEqual(formatHHMMSS(60), "00:01:00")
    }

    func test_formatHHMMSS_oneHour() {
        XCTAssertEqual(formatHHMMSS(3600), "01:00:00")
    }

    func test_formatHHMMSS_complexTime() {
        XCTAssertEqual(formatHHMMSS(3723), "01:02:03")
    }

    func test_formatHHMMSS_100hours() {
        XCTAssertEqual(formatHHMMSS(360000), "100:00:00")
    }

    func test_formatHHMMSS_negative_clampedToZero() {
        XCTAssertEqual(formatHHMMSS(-10), "00:00:00")
    }

    func test_formatHumanShort_zero() {
        XCTAssertEqual(formatHumanShort(0), "0m")
    }

    func test_formatHumanShort_30minutes() {
        XCTAssertEqual(formatHumanShort(1800), "30m")
    }

    func test_formatHumanShort_oneHour() {
        XCTAssertEqual(formatHumanShort(3600), "1h 0m")
    }

    func test_formatHumanShort_fiveHours42Minutes() {
        XCTAssertEqual(formatHumanShort(5 * 3600 + 42 * 60), "5h 42m")
    }
}
