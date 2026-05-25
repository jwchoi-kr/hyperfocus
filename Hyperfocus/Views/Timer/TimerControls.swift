import SwiftUI

struct TimerControls: View {
    @Environment(TimerStore.self) private var timerStore
    @State private var showingResetConfirm = false

    var body: some View {
        VStack(spacing: 10) {
            if timerStore.isRunning {
                // running: 세션 있음 + 타이머 동작 중
                HStack(spacing: 10) {
                    Button("일시정지") { timerStore.pause() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    Button("세션 리셋") { timerStore.resetSession() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                }
            } else if timerStore.activeSession != nil {
                // paused: 세션 있음 + 타이머 정지
                HStack(spacing: 10) {
                    Button("계속") { timerStore.start() }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    Button("세션 리셋") { timerStore.resetSession() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                }
            } else {
                // idle: 세션 없음
                Button("시작") { timerStore.start() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }

            Button(role: .destructive) {
                showingResetConfirm = true
            } label: {
                Text("전체 리셋")
                    .frame(maxWidth: .infinity)
            }
            .confirmationDialog(
                "현재 주기를 마감하고 통계에 보관합니다. 계속하시겠습니까?",
                isPresented: $showingResetConfirm,
                titleVisibility: .visible
            ) {
                Button("리셋", role: .destructive) { timerStore.resetTotal() }
                Button("취소", role: .cancel) {}
            }
        }
    }
}
