import SwiftUI

private let hhmmFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f
}()

// MARK: - Card

struct DayCard: View {
    let date: Date
    let totalDuration: TimeInterval
    let startTime: Date?
    let endTime: Date?
    let sessions: [Session]
    /// 진행 중 세션 여부 판별. 과거 날짜는 항상 false이므로 기본값 제공.
    var isSessionActive: (Session) -> Bool = { _ in false }
    let onRenameSession: (Session, String) -> Void
    let onDeleteSession: (Session) -> Void

    @State private var editingSessionID: UUID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DayCardHeader(
                date: date,
                totalDuration: totalDuration,
                startTime: startTime,
                endTime: endTime
            )

            if !sessions.isEmpty {
                Divider()
                VStack(spacing: 5) {
                    ForEach(sessions) { session in
                        DaySessionRow(
                            session: session,
                            totalDuration: totalDuration,
                            isEditing: editingSessionID == session.id,
                            isActive: isSessionActive(session),
                            onStartEdit: { editingSessionID = session.id },
                            onCommitEdit: { name in
                                onRenameSession(session, name)
                                editingSessionID = nil
                            },
                            onCancelEdit: { editingSessionID = nil },
                            onDelete: { onDeleteSession(session) }
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Header

struct DayCardHeader: View {
    let date: Date
    let totalDuration: TimeInterval
    let startTime: Date?
    let endTime: Date?

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.dayFormatter.string(from: date))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(formatHumanShort(totalDuration))
                    .font(.title2.bold())
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Grid(horizontalSpacing: 8, verticalSpacing: 2) {
                if let start = startTime {
                    GridRow {
                        Text("Start")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .gridColumnAlignment(.leading)
                        Text(hhmmFormatter.string(from: start))
                            .font(.system(size: 13).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .gridColumnAlignment(.trailing)
                    }
                }
                if let end = endTime {
                    GridRow {
                        Text("End")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .gridColumnAlignment(.leading)
                        Text(hhmmFormatter.string(from: end))
                            .font(.system(size: 13).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .gridColumnAlignment(.trailing)
                    }
                }
            }
        }
    }
}

// MARK: - Session Row

struct DaySessionRow: View {
    let session: Session
    let totalDuration: TimeInterval
    let isEditing: Bool
    var isActive: Bool = false
    let onStartEdit: () -> Void
    let onCommitEdit: (String) -> Void
    let onCancelEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var isDeleting = false
    @State private var editingText = ""
    @FocusState private var isEditFieldFocused: Bool

    private var percent: Int {
        guard totalDuration > 0 else { return 0 }
        return Int((session.duration / totalDuration * 100).rounded())
    }

    private var endTime: Date {
        session.startedAt.addingTimeInterval(session.duration)
    }

    var body: some View {
        if isDeleting {
            deleteConfirmRow
        } else {
            normalRow
        }
    }

    private var deleteConfirmRow: some View {
        HStack(spacing: 6) {
            Button("Delete") {
                onDelete()
                isDeleting = false
            }
            .font(.system(size: 13).bold())
            .foregroundStyle(.red)
            .buttonStyle(.borderless)
            Button("Cancel") { isDeleting = false }
                .font(.system(size: 13))
                .buttonStyle(.borderless)
            Spacer()
        }
    }

    private var normalRow: some View {
        HStack(alignment: .bottom, spacing: 12) {
            HStack(spacing: 4) {
                if isEditing {
                    TextField("Title", text: $editingText)
                        .focused($isEditFieldFocused)
                        .font(.system(size: 13))
                        .onSubmit { onCommitEdit(editingText) }
                        .onKeyPress(.escape) {
                            onCancelEdit()
                            return .handled
                        }
                        .onAppear {
                            let trimmed = session.name.trimmingCharacters(in: .whitespaces)
                            editingText = trimmed
                            isEditFieldFocused = true
                        }
                } else {
                    Text(normalizedSessionName(session.name))
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Button {
                        onStartEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .opacity(isHovered ? 1 : 0)
                    .allowsHitTesting(isHovered)

                    if !isActive {
                        Button { isDeleting = true } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .opacity(isHovered ? 1 : 0)
                        .allowsHitTesting(isHovered)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(formatHumanShort(session.duration))
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(.secondary)

            if totalDuration > 0 {
                Text("\(percent)%")
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 28, alignment: .trailing)
            }

            Text("\(hhmmFormatter.string(from: session.startedAt))-\(hhmmFormatter.string(from: endTime))")
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}
