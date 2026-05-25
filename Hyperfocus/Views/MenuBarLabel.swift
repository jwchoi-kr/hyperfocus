import SwiftUI

// Reads from @Environment so @Observable tracking works correctly inside MenuBarExtra label.
struct MenuBarLabel: View {
    @Environment(TimerStore.self) private var timerStore

    var body: some View {
        if timerStore.isRunning {
            Text(formatHHMMSS(timerStore.currentSessionDuration))
                .monospacedDigit()
                .frame(minWidth: 72)
        } else {
            Image(systemName: "stopwatch")
        }
    }
}
