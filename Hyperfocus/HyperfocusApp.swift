import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.hyperfocus", category: "App")

@main
struct HyperfocusApp: App {
    private let persistence = Persistence()
    private let timerStore: TimerStore
    private let statsStore: StatisticsStore
    private let focusStore: FocusStore
    private let focusBlocker: FocusBlocker
    private let macOSFocusBridge = MacOSFocusBridge()
    private let sleepObserver: SleepObserver

    init() {
        let state = persistence.load()
        let stats = StatisticsStore(pastDays: state.pastDays)
        let timer = TimerStore(
            currentDay: state.currentDay,
            activeSession: state.activeSession
        )
        let focus = FocusStore(blocklist: state.focusBlocklist)
        let blocker = FocusBlocker()

        self.statsStore = stats
        self.timerStore = timer
        self.focusStore = focus
        self.focusBlocker = blocker

        let bridge = macOSFocusBridge

        // Catch up on any 6am rollovers that happened while app was closed
        timer.checkAndPerformRollover()

        // Wire day-closed callback
        timer.onDayClosed = { [weak stats] day in
            stats?.appendClosedDay(day)
        }

        // Wire state-changed callbacks to trigger debounced persistence
        let p = persistence
        let saveState = { [weak timer, weak stats, weak focus] in
            guard let t = timer, let s = stats, let f = focus else { return }
            p.requestSave(PersistedState(
                currentDay: t.currentDay,
                pastDays: s.pastDays,
                activeSession: t.activeSession,
                focusBlocklist: f.currentBlocklist
            ))
        }
        timer.onStateChanged = saveState
        stats.onStateChanged = saveState
        focus.onStateChanged = { [weak blocker, weak focus, weak timer] in
            guard let f = focus else { return }
            blocker?.updateBlocklist(f.currentBlocklist)
            // If the macOS Focus toggle changed while a session is running, apply immediately
            if timer?.isRunning == true {
                if f.isMacOSFocusEnabled { bridge.activate() } else { bridge.deactivate() }
            }
            saveState()
        }

        // Activate/deactivate blocking when timer starts/stops
        timer.onBlockingStart = { [weak blocker, weak focus] in
            guard let f = focus else { return }
            blocker?.activate(blocklist: f.currentBlocklist)
            if f.isMacOSFocusEnabled { bridge.activate() }
        }
        timer.onBlockingStop = { [weak blocker, weak focus] in
            blocker?.deactivate()
            if focus?.isMacOSFocusEnabled == true { bridge.deactivate() }
        }

        // Auto-pause and immediate flush before system sleep; rollover check on wake
        self.sleepObserver = SleepObserver(
            onSleep: { [weak timer, weak stats, weak focus] in
                guard let t = timer else { return }
                t.pauseForSleep()
                guard let s = stats, let f = focus else { return }
                p.saveNow(PersistedState(
                    currentDay: t.currentDay,
                    pastDays: s.pastDays,
                    activeSession: t.activeSession,
                    focusBlocklist: f.currentBlocklist
                ))
                logger.info("State flushed before sleep")
            },
            onWake: { [weak timer] in
                timer?.checkAndPerformRollover()
                logger.info("Rollover check on wake")
            }
        )

        // Final flush on quit — deactivate blocker first so blocked apps stay closed
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak timer, weak stats, weak focus, weak blocker] _ in
            blocker?.deactivate()
            if focus?.isMacOSFocusEnabled == true { bridge.deactivate() }
            guard let t = timer, let s = stats, let f = focus else { return }
            p.saveNow(PersistedState(
                currentDay: t.currentDay,
                pastDays: s.pastDays,
                activeSession: t.activeSession,
                focusBlocklist: f.currentBlocklist
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
                .environment(focusStore)
        } label: {
            // Inject environment so MenuBarLabel's @Observable tracking works correctly.
            MenuBarLabel()
                .environment(timerStore)
        }
        .menuBarExtraStyle(.window)
    }
}
