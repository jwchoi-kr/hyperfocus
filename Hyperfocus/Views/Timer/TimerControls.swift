import SwiftUI

struct TimerControls: View {
    @Environment(TimerStore.self) private var timerStore
    let onShowStats: () -> Void
    let onShowFocus: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.bottom, 10)

            primaryButtons
                .padding(.bottom, 10)

            Divider()
                .padding(.bottom, 10)

            secondaryButtons
        }
    }

    @ViewBuilder
    private var primaryButtons: some View {
        if timerStore.isRunning {
            // running: Pause (gray) + End (red)
            HStack(spacing: 10) {
                Button("Pause") { timerStore.pause() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                Button("End") { timerStore.resetSession() }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .frame(maxWidth: .infinity)
            }
        } else if timerStore.activeSession != nil {
            // paused: Resume (blue) + End (red)
            HStack(spacing: 10) {
                Button("Resume") { timerStore.start() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                Button("End") { timerStore.resetSession() }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .frame(maxWidth: .infinity)
            }
        } else {
            // idle: Start (blue)
            Button("Start") { timerStore.start() }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
    }

    private var secondaryButtons: some View {
        HStack(spacing: 10) {
            Button("Stats") { onShowStats() }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            Button("Focus") { onShowFocus() }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
        }
    }
}
