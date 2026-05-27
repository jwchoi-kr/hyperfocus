import XCTest
@testable import Hyperfocus

final class SessionAggregationTests: XCTestCase {

    func test_emptyName_normalizedToUnnamed() {
        XCTAssertEqual(normalizedSessionName(""), "(Untitled)")
    }

    func test_whitespaceOnlyName_normalizedToUnnamed() {
        XCTAssertEqual(normalizedSessionName("   "), "(Untitled)")
    }

    func test_normalName_returnedAsIs() {
        XCTAssertEqual(normalizedSessionName("React"), "React")
    }

    func test_leadingTrailingWhitespaceTrimmed() {
        XCTAssertEqual(normalizedSessionName("  React  "), "React")
    }
}
