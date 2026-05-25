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

    // MARK: - endDay

    func test_endDay_commitsNonZeroSession() {
        let store = makeStore(activeSession: Session(name: "마지막", duration: 80))
        var calledWith: Day?
        store.onDayClosed = { calledWith = $0 }
        store.endDay()
        XCTAssertEqual(calledWith?.sessions.count, 1)
        XCTAssertEqual(calledWith?.sessions[0].name, "마지막")
    }

    func test_endDay_doesNotCommitZeroDurationSession() {
        let store = makeStore(activeSession: Session(duration: 0))
        var calledWith: Day?
        store.onDayClosed = { calledWith = $0 }
        store.endDay()
        XCTAssertTrue(calledWith?.sessions.isEmpty ?? true)
    }

    func test_endDay_emptyDay_doesNotCallOnDayClosed() {
        // SPEC §10: 빈 하루는 과거 목록에 추가하지 않음
        let store = makeStore()
        var closed = false
        store.onDayClosed = { _ in closed = true }
        store.endDay()
        XCTAssertFalse(closed)
    }

    func test_endDay_stopsTimer() {
        let store = makeStore(activeSession: Session(duration: 10))
        store.start()
        store.endDay()
        XCTAssertFalse(store.isRunning)
    }

    func test_endDay_resetsTimersToZero() {
        let store = makeStore(activeSession: Session(duration: 10))
        store.endDay()
        XCTAssertEqual(store.currentSessionDuration, 0)
        XCTAssertEqual(store.totalDuration, 0)
    }

    func test_endDay_emptyDayWithStopState_doesNotFire() {
        // SPEC §10: 진행 중 세션이 한 번도 시작되지 않은 빈 하루에서 종료
        let store = makeStore()
        var fired = false
        store.onDayClosed = { _ in fired = true }
        store.endDay()
        XCTAssertFalse(fired)
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
