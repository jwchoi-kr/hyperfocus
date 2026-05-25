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
        XCTAssertTrue(state.pastCycles.isEmpty)
        XCTAssertNil(state.activeSession)
    }

    func test_roundTrip_preservesSchemaVersion() {
        let p = Persistence(fileURL: tempURL)
        let original = PersistedState(schemaVersion: 1)
        p.saveNow(original)
        let loaded = p.load()
        XCTAssertEqual(loaded.schemaVersion, 1)
    }

    func test_roundTrip_preservesCurrentCycle() {
        let p = Persistence(fileURL: tempURL)
        let cycle = Cycle(sessions: [Session(name: "Test", duration: 100)])
        let state = PersistedState(currentCycle: cycle)
        p.saveNow(state)
        let loaded = p.load()
        XCTAssertEqual(loaded.currentCycle.sessions.count, 1)
        XCTAssertEqual(loaded.currentCycle.sessions[0].name, "Test")
        XCTAssertEqual(loaded.currentCycle.sessions[0].duration, 100)
    }

    func test_roundTrip_preservesPastCycles() {
        let p = Persistence(fileURL: tempURL)
        let past = Cycle(
            startedAt: Date(timeIntervalSinceReferenceDate: 0),
            endedAt: Date(timeIntervalSinceReferenceDate: 3600),
            sessions: [Session(name: "Past", duration: 200)]
        )
        let state = PersistedState(pastCycles: [past])
        p.saveNow(state)
        let loaded = p.load()
        XCTAssertEqual(loaded.pastCycles.count, 1)
        XCTAssertEqual(loaded.pastCycles[0].sessions[0].name, "Past")
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
}
