import Foundation
import Combine
import os.log

private let logger = Logger(subsystem: "com.hyperfocus", category: "TimerStore")

@Observable
final class TimerStore {
    private(set) var currentDay: Day
    private(set) var activeSession: Session?
    private(set) var isRunning: Bool = false

    var onDayClosed: ((Day) -> Void)?
    var onStateChanged: (() -> Void)?

    private var lastTickAt: Date?
    private var timerCancellable: AnyCancellable?
    private var rolloverCancellable: AnyCancellable?
    private let clock: ClockProtocol

    var currentSessionDuration: TimeInterval {
        activeSession?.duration ?? 0
    }

    var totalDuration: TimeInterval {
        currentDay.sessions.reduce(0) { $0 + $1.duration } + currentSessionDuration
    }

    init(
        currentDay: Day = Day(),
        activeSession: Session? = nil,
        clock: ClockProtocol = SystemClock()
    ) {
        self.currentDay = currentDay
        self.activeSession = activeSession
        self.clock = clock
    }

    func start() {
        guard !isRunning else { return }

        if activeSession == nil {
            activeSession = Session(startedAt: clock.now)
        }

        isRunning = true
        lastTickAt = clock.now
        startTicking()

        logger.info("Timer started")
        onStateChanged?()
    }

    func pause() {
        pauseInternal(saveImmediately: false)
    }

    func pauseForSleep() {
        pauseInternal(saveImmediately: true)
    }

    func resetSession() {
        if isRunning {
            stopTicking()
            isRunning = false
        }

        commitActiveSessionIfNeeded()
        activeSession = nil

        logger.info("Session reset → idle")
        onStateChanged?()
    }

    func updateActiveSessionName(_ name: String) {
        activeSession?.name = name
        onStateChanged?()
    }

    func renameSession(id sessionID: UUID, to newTitle: String) {
        let normalized = normalizedSessionName(newTitle)
        if let idx = currentDay.sessions.firstIndex(where: { $0.id == sessionID }) {
            currentDay.sessions[idx].name = normalized
        }
        if activeSession?.id == sessionID {
            activeSession?.name = normalized
        }
        logger.info("Renamed session \(sessionID) → '\(normalized)' in current day")
        onStateChanged?()
    }

    func deleteSession(id sessionID: UUID) {
        currentDay.sessions.removeAll { $0.id == sessionID }
        logger.info("Deleted session \(sessionID) from current day")
        onStateChanged?()
    }

    /// 앱 시작·wake 시 호출. 새벽 6시 경계를 넘은 횟수만큼 반복 롤오버를 수행한다.
    /// 여러 날이 지나서 재시작된 경우에도 currentDay.startedAt이 최신 경계로 업데이트된다 (SPEC §5.5).
    func checkAndPerformRollover() {
        var boundary = next6AM(after: currentDay.startedAt)
        while clock.now >= boundary {
            performRollover(closingAt: boundary)
            boundary = next6AM(after: currentDay.startedAt)
        }
        scheduleNextRollover()
    }

    // MARK: - Private

    private func pauseInternal(saveImmediately: Bool) {
        guard isRunning else { return }
        stopTicking()
        isRunning = false
        lastTickAt = nil

        logger.info("Timer paused (immediate=\(saveImmediately))")
        onStateChanged?()
    }

    private func performRollover(closingAt boundary: Date) {
        if isRunning {
            pauseInternal(saveImmediately: false)
        }
        commitActiveSessionIfNeeded()

        var closed = currentDay
        closed.endedAt = boundary

        if !closed.isEmpty {
            onDayClosed?(closed)
            logger.info("Rollover: day closed with \(closed.sessions.count) sessions at \(boundary)")
        } else {
            logger.info("Rollover: empty day discarded")
        }

        currentDay = Day(startedAt: boundary)
        activeSession = nil
        lastTickAt = nil

        logger.info("Rollover complete → idle")
        onStateChanged?()
    }

    private func scheduleNextRollover() {
        rolloverCancellable?.cancel()
        let now = clock.now
        let next = next6AM(after: now)
        let delay = next.timeIntervalSince(now)
        rolloverCancellable = Just(())
            .delay(for: .seconds(delay), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.performRollover(closingAt: self.next6AM(after: self.currentDay.startedAt))
                self.scheduleNextRollover()
            }
        logger.info("Next rollover scheduled in \(Int(delay))s")
    }

    /// currentDay.startedAt 이후의 첫 새벽 6시를 반환한다.
    private func next6AM(after date: Date) -> Date {
        let cal = Calendar.current
        var components = cal.dateComponents([.year, .month, .day], from: date)
        components.hour = 6
        components.minute = 0
        components.second = 0
        let sameDay6AM = cal.date(from: components)!
        // date가 이미 6시 이후라면 다음 날 6시
        if sameDay6AM > date {
            return sameDay6AM
        }
        return cal.date(byAdding: .day, value: 1, to: sameDay6AM)!
    }

    private func commitActiveSessionIfNeeded() {
        guard let session = activeSession, session.duration > 0 else { return }
        var toSave = session
        toSave.name = normalizedSessionName(session.name)
        currentDay.sessions.append(toSave)
        logger.info("Session committed: '\(toSave.name)' \(toSave.duration)s")
    }

    private func startTicking() {
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func stopTicking() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func tick() {
        guard isRunning, let lastTick = lastTickAt else { return }
        let now = clock.now
        activeSession?.duration += now.timeIntervalSince(lastTick)
        lastTickAt = now
    }
}
