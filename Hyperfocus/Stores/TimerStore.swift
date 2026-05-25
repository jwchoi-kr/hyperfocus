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

    func endDay() {
        commitActiveSessionIfNeeded()

        if isRunning {
            stopTicking()
            isRunning = false
        }

        var closed = currentDay
        closed.endedAt = clock.now

        if !closed.isEmpty {
            onDayClosed?(closed)
            logger.info("Day closed: \(closed.sessions.count) sessions")
        } else {
            logger.info("Empty day discarded on end")
        }

        currentDay = Day(startedAt: clock.now)
        activeSession = nil
        lastTickAt = nil

        logger.info("Day ended")
        onStateChanged?()
    }

    func updateActiveSessionName(_ name: String) {
        activeSession?.name = name
        onStateChanged?()
    }

    /// 앱 시작·wake 시 호출. 마지막 저장 하루의 새벽 6시 경계를 넘었으면 자동 마감 수행.
    /// 마감 후 다음 새벽 6시로 인앱 롤오버 타이머를 재스케줄한다 (SPEC §5.5).
    func checkAndPerformRollover() {
        let now = clock.now
        let boundary = next6AM(after: currentDay.startedAt)
        if now >= boundary {
            performRollover(closingAt: boundary)
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
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
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
