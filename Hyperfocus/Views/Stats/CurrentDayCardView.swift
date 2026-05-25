import SwiftUI

struct CurrentDayCardView: View {
    @Environment(TimerStore.self) private var timerStore
    @Environment(StatisticsStore.self) private var statsStore

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    var body: some View {
        let aggregated = statsStore.aggregatedSessionsIncluding(
            day: timerStore.currentDay,
            active: timerStore.activeSession
        )
        let totalDuration = timerStore.totalDuration

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("오늘")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Self.dateFormatter.string(from: timerStore.currentDay.startedAt)) 시작")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(formatHumanShort(totalDuration))
                .font(.title3.bold())

            if aggregated.isEmpty {
                Text("아직 세션 없음")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Divider()
                ForEach(aggregated) { item in
                    HStack {
                        Text(item.name)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(formatHumanShort(item.totalDuration))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
