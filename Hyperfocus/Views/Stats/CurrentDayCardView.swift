import SwiftUI

struct CurrentDayCardView: View {
    @Environment(TimerStore.self) private var timerStore

    private var sessions: [Session] {
        var all = timerStore.currentDay.sessions
        if let active = timerStore.activeSession, active.duration > 0 {
            all.append(active)
        }
        return all.sorted { $0.startedAt < $1.startedAt }
    }

    var body: some View {
        let totalDuration = timerStore.totalDuration
        let startTime: Date? = timerStore.currentDay.sessions.first?.startedAt
            ?? timerStore.activeSession?.startedAt
        let lastEndTime: Date? = {
            if let ended = timerStore.currentDay.endedAt { return ended }
            // 진행 중인 세션이 있으면 duration이 매 초 갱신되므로 실시간으로 반영된다.
            if let active = timerStore.activeSession, active.duration > 0 {
                return active.startedAt.addingTimeInterval(active.duration)
            }
            if let last = timerStore.currentDay.sessions.last {
                return last.startedAt.addingTimeInterval(last.duration)
            }
            return nil
        }()

        DayCard(
            date: Date(),
            totalDuration: totalDuration,
            startTime: startTime,
            endTime: lastEndTime,
            sessions: sessions,
            isSessionActive: { $0.id == timerStore.activeSession?.id },
            onRenameSession: { session, name in
                if session.id == timerStore.activeSession?.id {
                    timerStore.updateActiveSessionName(name)
                } else {
                    timerStore.renameSession(id: session.id, to: name)
                }
            },
            onDeleteSession: { session in
                timerStore.deleteSession(id: session.id)
            }
        )
    }
}
