import SwiftUI

// Reads from @Environment so @Observable tracking works correctly inside MenuBarExtra label.
struct MenuBarLabel: View {
    @Environment(TimerStore.self) private var timerStore

    var body: some View {
        Text(formatHHMMSS(timerStore.isRunning ? timerStore.currentSessionDuration : 0))
            .font(.system(size: 11, weight: .regular, design: .monospaced))
    }
}
