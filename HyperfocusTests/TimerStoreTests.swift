import XCTest
@testable import Hyperfocus

final class TimerStoreTests: XCTestCase {

    // MARK: - Helpers

    private func makeStore(
        clock: MockClock = MockClock(),
        currentCycle: Cycle = Cycle(),
        activeSession: Session? = nil
    ) -> TimerStore {
        TimerStore(currentCycle: currentCycle, activeSession: activeSession, clock: clock)
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
        var cycle = Cycle()
        cycle.sessions = [past]
        let store = makeStore(currentCycle: cycle, activeSession: Session(duration: 60))
        XCTAssertEqual(store.totalDuration, 180, accuracy: 0.001)
    }

    // MARK: - resetSession

    func test_resetSession_savesSessionWithPositiveDuration() {
        let store = makeStore(activeSession: Session(name: "작업", duration: 50))
        store.resetSession()
        XCTAssertEqual(store.currentCycle.sessions.count, 1)
        XCTAssertEqual(store.currentCycle.sessions[0].name, "작업")
    }

    func test_resetSession_doesNotSaveZeroDurationSession() {
        let store = makeStore(activeSession: Session(name: "빈", duration: 0))
        store.resetSession()
        XCTAssertTrue(store.currentCycle.sessions.isEmpty)
    }

    func test_resetSession_clearsActiveSessionDuration() {
        let store = makeStore(activeSession: Session(duration: 50))
        store.resetSession()
        XCTAssertEqual(store.currentSessionDuration, 0)
    }

    func test_resetSession_preservesTotalDuration() {
        let past = Session(name: "이전", duration: 100)
        var cycle = Cycle()
        cycle.sessions = [past]
        let store = makeStore(currentCycle: cycle, activeSession: Session(duration: 50))
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
        XCTAssertEqual(store.currentCycle.sessions.count, 1)
    }

    func test_resetSession_immediatelyAfterStart_doesNotRecord() {
        // SPEC §10: 시작 직후 곧바로 세션 리셋 → 기록 안 됨, idle 복귀
        let store = makeStore()
        store.start()
        store.resetSession()
        XCTAssertTrue(store.currentCycle.sessions.isEmpty)
        XCTAssertNil(store.activeSession)
        XCTAssertFalse(store.isRunning)
    }

    // MARK: - resetTotal

    func test_resetTotal_commitsNonZeroSession() {
        let store = makeStore(activeSession: Session(name: "마지막", duration: 80))
        var calledWith: Cycle?
        store.onCycleClosed = { calledWith = $0 }
        store.resetTotal()
        XCTAssertEqual(calledWith?.sessions.count, 1)
        XCTAssertEqual(calledWith?.sessions[0].name, "마지막")
    }

    func test_resetTotal_doesNotCommitZeroDurationSession() {
        let store = makeStore(activeSession: Session(duration: 0))
        var calledWith: Cycle?
        store.onCycleClosed = { calledWith = $0 }
        store.resetTotal()
        XCTAssertTrue(calledWith?.sessions.isEmpty ?? true)
    }

    func test_resetTotal_emptyCycle_doesNotCallOnCycleClosed() {
        // SPEC §10: 빈 주기는 과거 목록에 추가하지 않음
        let store = makeStore()
        var closed = false
        store.onCycleClosed = { _ in closed = true }
        store.resetTotal()
        XCTAssertFalse(closed)
    }

    func test_resetTotal_stopsTimer() {
        let store = makeStore(activeSession: Session(duration: 10))
        store.start()
        store.resetTotal()
        XCTAssertFalse(store.isRunning)
    }

    func test_resetTotal_resetsTimersToZero() {
        let store = makeStore(activeSession: Session(duration: 10))
        store.resetTotal()
        XCTAssertEqual(store.currentSessionDuration, 0)
        XCTAssertEqual(store.totalDuration, 0)
    }

    func test_resetTotal_emptyCycleWithStopState_doesNotFire() {
        // SPEC §10: 진행 중 세션이 한 번도 시작되지 않은 빈 주기에서 전체 리셋
        let store = makeStore()
        var fired = false
        store.onCycleClosed = { _ in fired = true }
        store.resetTotal()
        XCTAssertFalse(fired)
    }

    // MARK: - session name normalization

    func test_resetSession_trimsWhitespaceInName() {
        let store = makeStore(activeSession: Session(name: "  작업  ", duration: 10))
        store.resetSession()
        XCTAssertEqual(store.currentCycle.sessions[0].name, "작업")
    }

    func test_resetSession_blankNameBecomesUnnamed() {
        let store = makeStore(activeSession: Session(name: "   ", duration: 10))
        store.resetSession()
        XCTAssertEqual(store.currentCycle.sessions[0].name, "(Untitled)")
    }

    func test_resetSession_emptyNameBecomesUnnamed() {
        let store = makeStore(activeSession: Session(name: "", duration: 10))
        store.resetSession()
        XCTAssertEqual(store.currentCycle.sessions[0].name, "(Untitled)")
    }

    // MARK: - updateActiveSessionName

    func test_updateActiveSessionName_updatesName() {
        let store = makeStore(activeSession: Session())
        store.updateActiveSessionName("새 이름")
        XCTAssertEqual(store.activeSession?.name, "새 이름")
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
