import SwiftUI

struct TitleField: View {
    @Environment(TimerStore.self) private var timerStore
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var originalText: String = ""
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
            syncFromStore()
            if isInputMode && timerStore.activeSession == nil && !timerStore.isRunning {
                // macOS에서 윈도우가 key 상태가 된 뒤 포커스를 설정해야 적용됨
                DispatchQueue.main.async { isFocused = true }
            }
        }
        .onChange(of: timerStore.activeSession?.id) { _, _ in
            syncFromStore()
        }
    }

    private func syncFromStore() {
        let saved = timerStore.activeSession?.name ?? ""
        text = saved
        originalText = saved
        isInputMode = saved.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func cancelEdit() {
        text = originalText
        timerStore.updateActiveSessionName(originalText)
        if !originalText.trimmingCharacters(in: .whitespaces).isEmpty {
            isInputMode = false
        }
        isFocused = false
    }

    private var inputView: some View {
        HStack(spacing: 6) {
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
                .onKeyPress(.escape) {
                    cancelEdit()
                    return .handled
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
                    // start()가 빈 이름으로 세션을 만들므로 입력된 텍스트를 즉시 전달
                    timerStore.updateActiveSessionName(text)
                    dismiss()
                }
            if !originalText.trimmingCharacters(in: .whitespaces).isEmpty {
                Button("Cancel") {
                    cancelEdit()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.subheadline)
            }
        }
    }

    private var displayView: some View {
        HStack(spacing: 6) {
            Text(text)
                .lineLimit(1)
                .truncationMode(.tail)
            Button {
                originalText = text
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
