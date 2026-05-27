import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.hyperfocus", category: "App")

@main
struct HyperfocusApp: App {
    private let persistence = Persistence()
    private let timerStore: TimerStore
    private let statsStore: StatisticsStore
    private let sleepObserver: SleepObserver

    init() {
        let state = persistence.load()
        let stats = StatisticsStore(pastDays: state.pastDays)
        let timer = TimerStore(
            currentDay: state.currentDay,
            activeSession: state.activeSession
        )
        self.statsStore = stats
        self.timerStore = timer

        // Catch up on any 6am rollovers that happened while app was closed
        timer.checkAndPerformRollover()

        // Wire day-closed callback
        timer.onDayClosed = { [weak stats] day in
            stats?.appendClosedDay(day)
        }

        // Wire state-changed callbacks to trigger debounced persistence
        let p = persistence
        let saveState = { [weak timer, weak stats] in
            guard let t = timer, let s = stats else { return }
            p.requestSave(PersistedState(
                currentDay: t.currentDay,
                pastDays: s.pastDays,
                activeSession: t.activeSession
            ))
        }
        timer.onStateChanged = saveState
        stats.onStateChanged = saveState

        // Auto-pause and immediate flush before system sleep; rollover check on wake
        self.sleepObserver = SleepObserver(
            onSleep: { [weak timer, weak stats] in
                guard let t = timer else { return }
                t.pauseForSleep()
                guard let s = stats else { return }
                p.saveNow(PersistedState(
                    currentDay: t.currentDay,
                    pastDays: s.pastDays,
                    activeSession: t.activeSession
                ))
                logger.info("State flushed before sleep")
            },
            onWake: { [weak timer] in
                timer?.checkAndPerformRollover()
                logger.info("Rollover check on wake")
            }
        )

        // Final flush on quit
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak timer, weak stats] _ in
            guard let t = timer, let s = stats else { return }
            p.saveNow(PersistedState(
                currentDay: t.currentDay,
                pastDays: s.pastDays,
                activeSession: t.activeSession
            ))
            logger.info("State flushed on termination")
        }

        logger.info("App initialized")
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverRoot()
                .environment(timerStore)
                .environment(statsStore)
        } label: {
            // Inject environment so MenuBarLabel's @Observable tracking works correctly.
            MenuBarLabel()
                .environment(timerStore)
        }
        .menuBarExtraStyle(.window)
    }
}
