import SwiftUI

struct TitleField: View {
    @Environment(TimerStore.self) private var timerStore
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var isInputMode: Bool = true
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isInputMode {
                inputView
            } else {
                displayView
            }
        }
        .onAppear {
            let saved = timerStore.activeSession?.name ?? ""
            text = saved
            isInputMode = saved.trimmingCharacters(in: .whitespaces).isEmpty
            if isInputMode && timerStore.activeSession == nil && !timerStore.isRunning {
                // macOS에서 윈도우가 key 상태가 된 뒤 포커스를 설정해야 적용됨
                DispatchQueue.main.async { isFocused = true }
            }
        }
        .onChange(of: timerStore.activeSession?.id) { _, _ in
            let saved = timerStore.activeSession?.name ?? ""
            text = saved
            isInputMode = saved.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private var inputView: some View {
        TextField("Title", text: $text)
            .textFieldStyle(.roundedBorder)
            .focused($isFocused)
            .onChange(of: text) { _, newValue in
                timerStore.updateActiveSessionName(newValue)
            }
            .onChange(of: isFocused) { _, focused in
                // 포커스를 잃을 때만 display 모드로 전환 (입력 중에는 모드 유지)
                if !focused && !text.trimmingCharacters(in: .whitespaces).isEmpty {
                    isInputMode = false
                }
            }
            .onSubmit {
                // idle 상태에서만 Return → 시작 + 팝오버 닫기 (SPEC §4.1, §5.1)
                guard timerStore.activeSession == nil && !timerStore.isRunning else {
                    if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                        isInputMode = false
                    }
                    return
                }
                timerStore.start()
                dismiss()
            }
    }

    private var displayView: some View {
        HStack(spacing: 6) {
            Text(text)
                .lineLimit(1)
                .truncationMode(.tail)
            Button {
                isInputMode = true
                DispatchQueue.main.async { isFocused = true }
            } label: {
                Image(systemName: "pencil")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
