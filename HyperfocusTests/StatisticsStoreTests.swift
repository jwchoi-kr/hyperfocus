import XCTest
@testable import Hyperfocus

final class StatisticsStoreTests: XCTestCase {

    // MARK: - Helpers

    private func makeSession(name: String = "작업", duration: TimeInterval = 60) -> Session {
        Session(name: name, duration: duration)
    }

    private func makeDay(sessions: [Session] = []) -> Day {
        var day = Day()
        day.sessions = sessions
        return day
    }

    private func makeStore(days: [Day]) -> StatisticsStore {
        StatisticsStore(pastDays: days)
    }

    // MARK: - renameSession

    func test_rename_changesTargetSession() {
        let session = makeSession(name: "작업A")
        let day = makeDay(sessions: [session])
        let store = makeStore(days: [day])

        store.renameSession(in: day, sessionID: session.id, to: "작업B")

        XCTAssertEqual(store.pastDays[0].sessions[0].name, "작업B")
    }

    func test_rename_doesNotAffectOtherSessions() {
        let sessionA = makeSession(name: "작업A")
        let sessionB = makeSession(name: "작업B")
        let day = makeDay(sessions: [sessionA, sessionB])
        let store = makeStore(days: [day])

        store.renameSession(in: day, sessionID: sessionA.id, to: "새이름")

        XCTAssertEqual(store.pastDays[0].sessions[1].name, "작업B")
    }

    func test_rename_sameNameSessions_onlyTargetRenamed() {
        // 이름이 같아도 id가 다른 세션은 각각 독립적으로 rename 가능
        let s1 = makeSession(name: "리액트")
        let s2 = makeSession(name: "리액트")
        let day = makeDay(sessions: [s1, s2])
        let store = makeStore(days: [day])

        store.renameSession(in: day, sessionID: s1.id, to: "리액트 복습")

        XCTAssertEqual(store.pastDays[0].sessions[0].name, "리액트 복습")
        XCTAssertEqual(store.pastDays[0].sessions[1].name, "리액트")
    }

    func test_rename_blankNewName_becomesUntitled() {
        let session = makeSession(name: "작업A")
        let day = makeDay(sessions: [session])
        let store = makeStore(days: [day])

        store.renameSession(in: day, sessionID: session.id, to: "   ")

        XCTAssertEqual(store.pastDays[0].sessions[0].name, "(Untitled)")
    }

    func test_rename_dayNotFound_noChange() {
        let session = makeSession(name: "작업A")
        let day = makeDay(sessions: [session])
        let otherDay = makeDay()
        let store = makeStore(days: [day])

        store.renameSession(in: otherDay, sessionID: session.id, to: "새이름")

        XCTAssertEqual(store.pastDays[0].sessions[0].name, "작업A")
    }

    func test_rename_triggersOnStateChanged() {
        let session = makeSession()
        let day = makeDay(sessions: [session])
        let store = makeStore(days: [day])
        var fired = false
        store.onStateChanged = { fired = true }

        store.renameSession(in: day, sessionID: session.id, to: "새이름")

        XCTAssertTrue(fired)
    }

    // MARK: - deleteSession

    func test_delete_removesTargetSession() {
        let s1 = makeSession(name: "작업A")
        let s2 = makeSession(name: "작업B")
        let day = makeDay(sessions: [s1, s2])
        let store = makeStore(days: [day])

        store.deleteSession(in: day, sessionID: s1.id)

        XCTAssertEqual(store.pastDays[0].sessions.count, 1)
        XCTAssertEqual(store.pastDays[0].sessions[0].name, "작업B")
    }

    func test_delete_sameNameSessions_onlyTargetDeleted() {
        // 이름이 같아도 id가 다른 세션은 하나만 삭제됨
        let s1 = makeSession(name: "리액트")
        let s2 = makeSession(name: "리액트")
        let day = makeDay(sessions: [s1, s2])
        let store = makeStore(days: [day])

        store.deleteSession(in: day, sessionID: s1.id)

        XCTAssertEqual(store.pastDays[0].sessions.count, 1)
        XCTAssertEqual(store.pastDays[0].sessions[0].id, s2.id)
    }

    func test_delete_lastSession_removesDayFromStore() {
        // SPEC §4.3: 마지막 세션 삭제 → 하루 자체가 목록에서 제거
        let session = makeSession()
        let day = makeDay(sessions: [session])
        let store = makeStore(days: [day])

        store.deleteSession(in: day, sessionID: session.id)

        XCTAssertTrue(store.pastDays.isEmpty)
    }

    func test_delete_dayNotFound_noChange() {
        let session = makeSession()
        let day = makeDay(sessions: [session])
        let otherDay = makeDay()
        let store = makeStore(days: [day])

        store.deleteSession(in: otherDay, sessionID: session.id)

        XCTAssertEqual(store.pastDays.count, 1)
    }

    func test_delete_triggersOnStateChanged() {
        let s1 = makeSession(name: "A")
        let s2 = makeSession(name: "B")
        let day = makeDay(sessions: [s1, s2])
        let store = makeStore(days: [day])
        var fired = false
        store.onStateChanged = { fired = true }

        store.deleteSession(in: day, sessionID: s1.id)

        XCTAssertTrue(fired)
    }

    func test_delete_multipleDays_onlyAffectsCorrectDay() {
        let s1 = makeSession(name: "작업")
        let s2 = makeSession(name: "작업")
        let dayA = makeDay(sessions: [s1])
        let dayB = makeDay(sessions: [s2])
        let store = makeStore(days: [dayA, dayB])

        store.deleteSession(in: dayA, sessionID: s1.id)

        // dayA deleted (became empty), dayB remains
        XCTAssertEqual(store.pastDays.count, 1)
        XCTAssertEqual(store.pastDays[0].id, dayB.id)
    }
}
