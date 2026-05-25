import SwiftUI

struct TimerControls: View {
    @Environment(TimerStore.self) private var timerStore
    let onShowStats: () -> Void

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
            // running: Pause + Reset
            HStack(spacing: 10) {
                Button("Pause") { timerStore.pause() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                Button("Reset") { timerStore.resetSession() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
            }
        } else if timerStore.activeSession != nil {
            // paused: Resume + Reset
            HStack(spacing: 10) {
                Button("Resume") { timerStore.start() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                Button("Reset") { timerStore.resetSession() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
            }
        } else {
            // idle: Start
            Button("Start") { timerStore.start() }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
    }

    private var secondaryButtons: some View {
        HStack(spacing: 10) {
            Button("End") { timerStore.endDay() }
                .buttonStyle(.bordered)
                .tint(.red)
                .frame(maxWidth: .infinity)

            Button("Stats") { onShowStats() }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
        }
    }
}
