import SwiftUI

struct SessionNameField: View {
    @Environment(TimerStore.self) private var timerStore
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("세션 이름 (선택)", text: $text)
            .textFieldStyle(.roundedBorder)
            .focused($isFocused)
            .onChange(of: text) { _, newValue in
                timerStore.updateActiveSessionName(newValue)
            }
            .onAppear {
                text = timerStore.activeSession?.name ?? ""
                if timerStore.activeSession == nil && !timerStore.isRunning {
                    // macOS에서 윈도우가 key 상태가 된 뒤 포커스를 설정해야 적용됨
                    DispatchQueue.main.async { isFocused = true }
                }
            }
            .onChange(of: timerStore.activeSession?.id) { _, _ in
                text = timerStore.activeSession?.name ?? ""
            }
            .onSubmit {
                // idle 상태에서만 Enter → 시작 + 팝오버 닫기 (SPEC §4.1, §5.1)
                guard timerStore.activeSession == nil && !timerStore.isRunning else { return }
                timerStore.start()
                dismiss()
            }
    }
}
