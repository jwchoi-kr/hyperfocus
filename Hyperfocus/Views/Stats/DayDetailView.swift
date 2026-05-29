import SwiftUI

struct DayDetailView: View {
    let day: Day
    let onBack: () -> Void

    @Environment(StatisticsStore.self) private var statsStore
    @Environment(TimerStore.self) private var timerStore

    // Look up the latest copy of this day so edits reflect immediately.
    // Today's day lives in timerStore, not statsStore.
    private var liveDay: Day? {
        if timerStore.currentDay.id == day.id {
            return timerStore.currentDay
        }
        return statsStore.pastDays.first { $0.id == day.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            Divider()

            if let day = liveDay {
                ScrollView {
                    DayCard(
                        date: day.startedAt,
                        totalDuration: day.totalDuration,
                        startTime: day.startedAt,
                        endTime: day.endedAt,
                        sessions: statsStore.sessions(of: day),
                        onRenameSession: { session, name in
                            statsStore.renameSession(in: day, sessionID: session.id, to: name)
                        },
                        onDeleteSession: { session in
                            statsStore.deleteSession(in: day, sessionID: session.id)
                        }
                    )
                    .padding()
                }
                .frame(maxHeight: .infinity)
            }
        }
        .onChange(of: liveDay == nil) { _, isGone in
            if isGone { onBack() }
        }
    }

    private static let titleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var navBar: some View {
        ZStack {
            Text(Self.titleFormatter.string(from: day.startedAt))
                .font(.headline)
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Stats")
                    }
                    .font(.footnote)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}
