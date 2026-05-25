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

    // MARK: - Private

    private func pauseInternal(saveImmediately: Bool) {
        guard isRunning else { return }
        stopTicking()
        isRunning = false
        lastTickAt = nil

        logger.info("Timer paused (immediate=\(saveImmediately))")
        onStateChanged?()
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
