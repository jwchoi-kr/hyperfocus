import SwiftUI
import AppKit

struct TimerScreen: View {
    @Environment(TimerStore.self) private var timerStore
    @Environment(\.dismiss) private var dismiss
    let onShowStats: () -> Void
    let onShowFocus: () -> Void

    @State private var spaceKeyMonitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TitleField()

            TimeDisplayView(
                currentDuration: timerStore.currentSessionDuration,
                totalDuration: timerStore.totalDuration
            )

            TimerControls(onShowStats: onShowStats, onShowFocus: onShowFocus)
        }
        .padding()
        .onAppear { setupSpaceKeyMonitor() }
        .onDisappear { teardownSpaceKeyMonitor() }
    }

    // MARK: - Space key shortcut (SPEC §3.2)
    // NSEvent monitor: SleepObserver와 동일 패턴으로 AppKit 이벤트를 직접 가로챔.
    // SwiftUI .onKeyPress는 포커스 체인에 의존해 idle/running 전환 시 신뢰성이 낮아 사용하지 않음.

    private func setupSpaceKeyMonitor() {
        guard spaceKeyMonitor == nil else { return }
        let store = timerStore
        let dismissAction = dismiss
        spaceKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == 49,  // 49 = Space (하드웨어 키코드, 키보드 레이아웃 무관)
                  event.modifierFlags.intersection([.shift, .control, .option, .command]).isEmpty,
                  // NSTextView는 NSTextField 내부 편집기 — first responder이면 텍스트 필드 포커스 중
                  !(NSApp.keyWindow?.firstResponder is NSTextView)
            else { return event }

            if store.isRunning {
                store.pause()
                return nil  // 이벤트 소비 — 텍스트 필드에 공백 입력 방지
            } else if store.activeSession != nil {
                store.start()
                dismissAction()
                return nil
            }
            return event  // idle: 텍스트 필드가 공백 문자로 처리하도록 통과
        }
    }

    private func teardownSpaceKeyMonitor() {
        if let monitor = spaceKeyMonitor {
            NSEvent.removeMonitor(monitor)
            spaceKeyMonitor = nil
        }
    }
}
