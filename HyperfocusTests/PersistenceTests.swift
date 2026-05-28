import XCTest
@testable import Hyperfocus

final class PersistenceTests: XCTestCase {
    private var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    func test_loadReturnsEmptyStateWhenNoFile() {
        let p = Persistence(fileURL: tempURL)
        let state = p.load()
        XCTAssertEqual(state.schemaVersion, 1)
        XCTAssertTrue(state.pastDays.isEmpty)
        XCTAssertNil(state.activeSession)
    }

    func test_roundTrip_preservesSchemaVersion() {
        let p = Persistence(fileURL: tempURL)
        let original = PersistedState(schemaVersion: 1)
        p.saveNow(original)
        let loaded = p.load()
        XCTAssertEqual(loaded.schemaVersion, 1)
    }

    func test_roundTrip_preservesCurrentDay() {
        let p = Persistence(fileURL: tempURL)
        let day = Day(sessions: [Session(name: "Test", duration: 100)])
        let state = PersistedState(currentDay: day)
        p.saveNow(state)
        let loaded = p.load()
        XCTAssertEqual(loaded.currentDay.sessions.count, 1)
        XCTAssertEqual(loaded.currentDay.sessions[0].name, "Test")
        XCTAssertEqual(loaded.currentDay.sessions[0].duration, 100)
    }

    func test_roundTrip_preservesPastDays() {
        let p = Persistence(fileURL: tempURL)
        let past = Day(
            startedAt: Date(timeIntervalSinceReferenceDate: 0),
            endedAt: Date(timeIntervalSinceReferenceDate: 3600),
            sessions: [Session(name: "Past", duration: 200)]
        )
        let state = PersistedState(pastDays: [past])
        p.saveNow(state)
        let loaded = p.load()
        XCTAssertEqual(loaded.pastDays.count, 1)
        XCTAssertEqual(loaded.pastDays[0].sessions[0].name, "Past")
    }

    func test_roundTrip_preservesActiveSession() {
        let p = Persistence(fileURL: tempURL)
        let session = Session(name: "Active", duration: 42)
        let state = PersistedState(activeSession: session)
        p.saveNow(state)
        let loaded = p.load()
        XCTAssertEqual(loaded.activeSession?.name, "Active")
        XCTAssertEqual(loaded.activeSession?.duration, 42)
    }

    func test_roundTrip_activeSessionNilPreserved() {
        let p = Persistence(fileURL: tempURL)
        let state = PersistedState(activeSession: nil)
        p.saveNow(state)
        let loaded = p.load()
        XCTAssertNil(loaded.activeSession)
    }

    func test_roundTrip_preservesFocusBlocklist() {
        let p = Persistence(fileURL: tempURL)
        let app = BlockedApp(id: UUID(), bundleIdentifier: "com.kakao.KakaoTalk", displayName: "카카오톡")
        let site = BlockedSite(id: UUID(), domain: "linkedin.com")
        let state = PersistedState(focusBlocklist: FocusBlocklist(blockedApps: [app], blockedSites: [site]))
        p.saveNow(state)
        let loaded = p.load()
        XCTAssertEqual(loaded.focusBlocklist.blockedApps.count, 1)
        XCTAssertEqual(loaded.focusBlocklist.blockedApps.first?.bundleIdentifier, "com.kakao.KakaoTalk")
        XCTAssertEqual(loaded.focusBlocklist.blockedSites.count, 1)
        XCTAssertEqual(loaded.focusBlocklist.blockedSites.first?.domain, "linkedin.com")
    }

    func test_loadingOldStateWithoutFocusBlocklist_returnsEmptyBlocklist() {
        let dayID = UUID().uuidString
        let oldJSON = """
        {
          "schemaVersion": 1,
          "currentDay": {"id": "\(dayID)", "startedAt": "2026-05-29T00:00:00Z", "sessions": []},
          "pastDays": []
        }
        """.data(using: .utf8)!
        try! oldJSON.write(to: tempURL)
        let p = Persistence(fileURL: tempURL)
        let state = p.load()
        XCTAssertTrue(state.focusBlocklist.blockedApps.isEmpty)
        XCTAssertTrue(state.focusBlocklist.blockedSites.isEmpty)
    }
}
