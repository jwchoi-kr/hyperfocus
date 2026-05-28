import XCTest
@testable import Hyperfocus

final class TimerStoreTests: XCTestCase {

    // MARK: - Helpers

    private func makeStore(
        clock: MockClock = MockClock(),
        currentDay: Day = Day(),
        activeSession: Session? = nil
    ) -> TimerStore {
        TimerStore(currentDay: currentDay, activeSession: activeSession, clock: clock)
    }

    // MARK: - start / pause

    func test_start_setsIsRunningTrue() {
        let store = makeStore()
        store.start()
        XCTAssertTrue(store.isRunning)
    }

    func test_start_createsActiveSessionWhenNoneExists() {
        let store = makeStore()
        store.start()
        XCTAssertNotNil(store.activeSession)
    }

    func test_start_doesNotReplaceExistingSession() {
        let existing = Session(name: "기존", duration: 100)
        let store = makeStore(activeSession: existing)
        store.start()
        XCTAssertEqual(store.activeSession?.name, "기존")
        XCTAssertEqual(store.activeSession?.duration, 100)
    }

    func test_pause_setsIsRunningFalse() {
        let store = makeStore()
        store.start()
        store.pause()
        XCTAssertFalse(store.isRunning)
    }

    func test_pause_preservesSessionDuration() {
        let clock = MockClock(date: Date(timeIntervalSinceReferenceDate: 0))
        let store = makeStore(clock: clock)
        store.start()
        clock.advance(by: 30)
        store.pause()
        XCTAssertEqual(store.currentSessionDuration, 0, accuracy: 0.001) // tick hasn't fired
    }

    // MARK: - currentSessionDuration / totalDuration

    func test_currentSessionDuration_isZeroWhenNoSession() {
        let store = makeStore()
        XCTAssertEqual(store.currentSessionDuration, 0)
    }

    func test_totalDuration_sumsPastAndCurrentSession() {
        let past = Session(name: "A", duration: 120)
        var day = Day()
        day.sessions = [past]
        let store = makeStore(currentDay: day, activeSession: Session(duration: 60))
        XCTAssertEqual(store.totalDuration, 180, accuracy: 0.001)
    }

    // MARK: - resetSession

    func test_resetSession_savesSessionWithPositiveDuration() {
        let store = makeStore(activeSession: Session(name: "작업", duration: 50))
        store.resetSession()
        XCTAssertEqual(store.currentDay.sessions.count, 1)
        XCTAssertEqual(store.currentDay.sessions[0].name, "작업")
    }

    func test_resetSession_doesNotSaveZeroDurationSession() {
        let store = makeStore(activeSession: Session(name: "빈", duration: 0))
        store.resetSession()
        XCTAssertTrue(store.currentDay.sessions.isEmpty)
    }

    func test_resetSession_clearsActiveSessionDuration() {
        let store = makeStore(activeSession: Session(duration: 50))
        store.resetSession()
        XCTAssertEqual(store.currentSessionDuration, 0)
    }

    func test_resetSession_preservesTotalDuration() {
        let past = Session(name: "이전", duration: 100)
        var day = Day()
        day.sessions = [past]
        let store = makeStore(currentDay: day, activeSession: Session(duration: 50))
        store.resetSession()
        // After reset: past(100) + committed(50) = 150 (no active session)
        XCTAssertEqual(store.totalDuration, 150, accuracy: 0.001)
    }

    func test_resetSession_setsActiveSessionToNil() {
        // SPEC §5.3: 세션 리셋 → idle 상태 (activeSession = nil)
        let store = makeStore(activeSession: Session(duration: 50))
        store.resetSession()
        XCTAssertNil(store.activeSession)
    }

    func test_resetSession_stopsTimerWhenRunning() {
        // SPEC §5.3: 실행 중 세션 리셋 → 타이머도 정지
        let store = makeStore()
        store.start()
        store.resetSession()
        XCTAssertFalse(store.isRunning)
        XCTAssertNil(store.activeSession)
    }

    func test_resetSession_idleStateWhenPaused() {
        // SPEC §10: 일시정지 중 세션 리셋 → idle 복귀
        let store = makeStore(activeSession: Session(duration: 30))
        // 정지 상태에서 리셋
        store.resetSession()
        XCTAssertFalse(store.isRunning)
        XCTAssertNil(store.activeSession)
        XCTAssertEqual(store.currentDay.sessions.count, 1)
    }

    func test_resetSession_immediatelyAfterStart_doesNotRecord() {
        // SPEC §10: 시작 직후 곧바로 세션 리셋 → 기록 안 됨, idle 복귀
        let store = makeStore()
        store.start()
        store.resetSession()
        XCTAssertTrue(store.currentDay.sessions.isEmpty)
        XCTAssertNil(store.activeSession)
        XCTAssertFalse(store.isRunning)
    }

    // MARK: - session name normalization

    func test_resetSession_trimsWhitespaceInName() {
        let store = makeStore(activeSession: Session(name: "  작업  ", duration: 10))
        store.resetSession()
        XCTAssertEqual(store.currentDay.sessions[0].name, "작업")
    }

    func test_resetSession_blankNameBecomesUnnamed() {
        let store = makeStore(activeSession: Session(name: "   ", duration: 10))
        store.resetSession()
        XCTAssertEqual(store.currentDay.sessions[0].name, "(Untitled)")
    }

    func test_resetSession_emptyNameBecomesUnnamed() {
        let store = makeStore(activeSession: Session(name: "", duration: 10))
        store.resetSession()
        XCTAssertEqual(store.currentDay.sessions[0].name, "(Untitled)")
    }

    // MARK: - updateActiveSessionName

    func test_updateActiveSessionName_updatesName() {
        let store = makeStore(activeSession: Session())
        store.updateActiveSessionName("새 이름")
        XCTAssertEqual(store.activeSession?.name, "새 이름")
    }

    // MARK: - checkAndPerformRollover (SPEC §5.5)

    // 날짜 생성 헬퍼: 로컬 시각 기준 년/월/일/시/분/초 지정
    private func localDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0, second: Int = 0) -> Date {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        c.hour = hour; c.minute = minute; c.second = second
        return cal.date(from: c)!
    }

    func test_rollover_noRolloverBeforeBoundary() {
        // currentDay가 5월 25일 08:00에 시작, 현재 시각이 같은 날 23:00 — 다음 6시 경계는 아직 안 넘음
        let dayStart = localDate(year: 2026, month: 5, day: 25, hour: 8)
        let clock = MockClock(date: localDate(year: 2026, month: 5, day: 25, hour: 23))
        let day = Day(startedAt: dayStart)
        let store = makeStore(clock: clock, currentDay: day)

        var closedDays: [Day] = []
        store.onDayClosed = { closedDays.append($0) }

        store.checkAndPerformRollover()

        XCTAssertTrue(closedDays.isEmpty, "6시 경계 전이라 rollover 없어야 함")
        XCTAssertEqual(store.currentDay.startedAt, dayStart)
    }

    func test_rollover_performsWhenPast6AM() {
        // currentDay가 5월 25일 08:00에 시작, 현재 시각이 5월 26일 07:00 — 경계(26일 06:00) 초과
        let dayStart = localDate(year: 2026, month: 5, day: 25, hour: 8)
        let clock = MockClock(date: localDate(year: 2026, month: 5, day: 26, hour: 7))
        let session = Session(name: "작업", duration: 3600)
        var day = Day(startedAt: dayStart)
        day.sessions.append(session)
        let store = makeStore(clock: clock, currentDay: day)

        var closedDays: [Day] = []
        store.onDayClosed = { closedDays.append($0) }

        store.checkAndPerformRollover()

        XCTAssertEqual(closedDays.count, 1, "하루가 마감되어야 함")
        XCTAssertEqual(store.currentDay.sessions.isEmpty, true, "새 하루는 빈 세션")
        XCTAssertNil(store.activeSession)
        XCTAssertFalse(store.isRunning)
    }

    func test_rollover_emptyDayNotAddedToPastDays() {
        // 빈 하루(세션 0개)에서 rollover → onDayClosed 호출 안 됨
        let dayStart = localDate(year: 2026, month: 5, day: 25, hour: 8)
        let clock = MockClock(date: localDate(year: 2026, month: 5, day: 26, hour: 7))
        let store = makeStore(clock: clock, currentDay: Day(startedAt: dayStart))

        var closedDays: [Day] = []
        store.onDayClosed = { closedDays.append($0) }

        store.checkAndPerformRollover()

        XCTAssertTrue(closedDays.isEmpty, "빈 하루는 통계에 추가되지 않아야 함")
    }

    func test_rollover_runningTimerAutoPaused() {
        // running 상태에서 rollover → idle로 전환
        let dayStart = localDate(year: 2026, month: 5, day: 25, hour: 8)
        let clock = MockClock(date: localDate(year: 2026, month: 5, day: 25, hour: 8))
        let store = makeStore(clock: clock, currentDay: Day(startedAt: dayStart))
        store.start()
        XCTAssertTrue(store.isRunning)

        clock.advance(by: 60)
        // 6시 경계를 넘긴 시각으로 이동
        let past6AM = localDate(year: 2026, month: 5, day: 26, hour: 7)
        let pastClock = MockClock(date: past6AM)
        let store2 = makeStore(clock: pastClock, currentDay: Day(startedAt: dayStart))
        store2.start()
        store2.checkAndPerformRollover()

        XCTAssertFalse(store2.isRunning, "rollover 후 idle이어야 함")
        XCTAssertNil(store2.activeSession)
    }

    func test_rollover_activeSessionCommittedWithNonZeroDuration() {
        // 진행 중 세션(duration > 0)이 있을 때 rollover → 마감 하루에 포함
        let dayStart = localDate(year: 2026, month: 5, day: 25, hour: 8)
        let clock = MockClock(date: localDate(year: 2026, month: 5, day: 26, hour: 7))
        let active = Session(name: "리뷰", duration: 1800)
        let store = makeStore(clock: clock, currentDay: Day(startedAt: dayStart), activeSession: active)

        var closedDays: [Day] = []
        store.onDayClosed = { closedDays.append($0) }

        store.checkAndPerformRollover()

        XCTAssertEqual(closedDays.first?.sessions.first?.name, "리뷰")
        XCTAssertNil(store.activeSession)
    }

    func test_rollover_multipleDaysSkipped_currentDayAdvancesToLatestBoundary() {
        // 앱이 3일 동안 꺼졌다 켜진 경우 — 모든 경계를 연속으로 처리해 currentDay가 최신 날짜로 이동해야 함
        let dayStart = localDate(year: 2026, month: 5, day: 23, hour: 8)
        let session = Session(name: "작업", duration: 3600)
        var day = Day(startedAt: dayStart)
        day.sessions.append(session)

        // 5/26 09:00 — 경계 5/24 06:00, 5/25 06:00, 5/26 06:00 세 개를 모두 넘음
        let clock = MockClock(date: localDate(year: 2026, month: 5, day: 26, hour: 9))
        let store = makeStore(clock: clock, currentDay: day)

        var closedDays: [Day] = []
        store.onDayClosed = { closedDays.append($0) }

        store.checkAndPerformRollover()

        // 5/23 하루만 non-empty → onDayClosed 1회 호출
        XCTAssertEqual(closedDays.count, 1)
        // currentDay.startedAt은 마지막 경계(5/26 06:00)여야 함 — 5/23이나 5/24가 아님
        let expectedBoundary = localDate(year: 2026, month: 5, day: 26, hour: 6)
        XCTAssertEqual(store.currentDay.startedAt, expectedBoundary)
    }

    // MARK: - renameSession (by id)

    func test_renameSession_renamesTargetSession() {
        let session = Session(name: "작업A", duration: 60)
        var day = Day()
        day.sessions = [session]
        let store = makeStore(currentDay: day)

        store.renameSession(id: session.id, to: "작업B")

        XCTAssertEqual(store.currentDay.sessions[0].name, "작업B")
    }

    func test_renameSession_sameNameSessions_onlyTargetRenamed() {
        // 이름이 같아도 id가 다른 세션은 각각 독립적으로 rename 가능
        let s1 = Session(name: "리액트", duration: 60)
        let s2 = Session(name: "리액트", duration: 30)
        var day = Day()
        day.sessions = [s1, s2]
        let store = makeStore(currentDay: day)

        store.renameSession(id: s1.id, to: "리액트 복습")

        XCTAssertEqual(store.currentDay.sessions[0].name, "리액트 복습")
        XCTAssertEqual(store.currentDay.sessions[1].name, "리액트")
    }

    func test_renameSession_alsoRenamesActiveSession() {
        let active = Session(name: "작업A", duration: 30)
        let store = makeStore(activeSession: active)

        store.renameSession(id: active.id, to: "작업B")

        XCTAssertEqual(store.activeSession?.name, "작업B")
    }

    func test_renameSession_blankNewName_becomesUntitled() {
        let session = Session(name: "작업A", duration: 60)
        var day = Day()
        day.sessions = [session]
        let store = makeStore(currentDay: day)

        store.renameSession(id: session.id, to: "   ")

        XCTAssertEqual(store.currentDay.sessions[0].name, "(Untitled)")
    }

    func test_renameSession_triggersOnStateChanged() {
        let session = Session(name: "A", duration: 60)
        var day = Day()
        day.sessions = [session]
        let store = makeStore(currentDay: day)
        var fired = false
        store.onStateChanged = { fired = true }

        store.renameSession(id: session.id, to: "B")

        XCTAssertTrue(fired)
    }

    // MARK: - deleteSession (by id)

    func test_deleteSession_removesTargetSession() {
        let s1 = Session(name: "작업A", duration: 60)
        let s2 = Session(name: "작업B", duration: 30)
        var day = Day()
        day.sessions = [s1, s2]
        let store = makeStore(currentDay: day)

        store.deleteSession(id: s1.id)

        XCTAssertEqual(store.currentDay.sessions.count, 1)
        XCTAssertEqual(store.currentDay.sessions[0].name, "작업B")
    }

    func test_deleteSession_sameNameSessions_onlyTargetDeleted() {
        // 이름이 같아도 id가 다른 세션은 하나만 삭제됨
        let s1 = Session(name: "리액트", duration: 60)
        let s2 = Session(name: "리액트", duration: 30)
        var day = Day()
        day.sessions = [s1, s2]
        let store = makeStore(currentDay: day)

        store.deleteSession(id: s1.id)

        XCTAssertEqual(store.currentDay.sessions.count, 1)
        XCTAssertEqual(store.currentDay.sessions[0].id, s2.id)
    }

    func test_deleteSession_doesNotRemoveDay() {
        // 현재 하루는 세션을 모두 삭제해도 Day 자체는 유지됨 (타이머의 컨테이너)
        let session = Session(name: "작업A", duration: 60)
        var day = Day()
        day.sessions = [session]
        let store = makeStore(currentDay: day)

        store.deleteSession(id: session.id)

        XCTAssertTrue(store.currentDay.sessions.isEmpty)
    }

    // MARK: - onBlockingStart / onBlockingStop

    func test_start_firesOnBlockingStart() {
        let store = makeStore()
        var fired = false
        store.onBlockingStart = { fired = true }
        store.start()
        XCTAssertTrue(fired)
    }

    func test_pause_firesOnBlockingStop() {
        let store = makeStore()
        store.start()
        var fired = false
        store.onBlockingStop = { fired = true }
        store.pause()
        XCTAssertTrue(fired)
    }

    func test_pause_whenNotRunning_doesNotFireOnBlockingStop() {
        let store = makeStore()
        var fired = false
        store.onBlockingStop = { fired = true }
        store.pause()
        XCTAssertFalse(fired)
    }

    func test_resetSession_whenRunning_firesOnBlockingStop() {
        let store = makeStore()
        store.start()
        var fired = false
        store.onBlockingStop = { fired = true }
        store.resetSession()
        XCTAssertTrue(fired)
    }

    func test_resetSession_whenIdle_doesNotFireOnBlockingStop() {
        let store = makeStore(activeSession: Session(duration: 30))
        var fired = false
        store.onBlockingStop = { fired = true }
        store.resetSession()
        XCTAssertFalse(fired)
    }

    func test_start_pause_start_firesCallbacksInOrder() {
        let store = makeStore()
        var events: [String] = []
        store.onBlockingStart = { events.append("start") }
        store.onBlockingStop = { events.append("stop") }
        store.start()
        store.pause()
        store.start()
        XCTAssertEqual(events, ["start", "stop", "start"])
    }

    func test_deleteSession_triggersOnStateChanged() {
        let s1 = Session(name: "A", duration: 60)
        let s2 = Session(name: "B", duration: 30)
        var day = Day()
        day.sessions = [s1, s2]
        let store = makeStore(currentDay: day)
        var fired = false
        store.onStateChanged = { fired = true }

        store.deleteSession(id: s1.id)

        XCTAssertTrue(fired)
    }
}

// MARK: - MockClock

final class MockClock: ClockProtocol {
    private var current: Date

    init(date: Date = Date()) {
        self.current = date
    }

    var now: Date { current }

    func advance(by seconds: TimeInterval) {
        current = current.addingTimeInterval(seconds)
    }
}
