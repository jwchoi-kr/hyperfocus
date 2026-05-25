import SwiftUI

struct DayDetailView: View {
    let day: Day
    let onBack: () -> Void

    @Environment(StatisticsStore.self) private var statsStore

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    var body: some View {
        let aggregated = statsStore.aggregatedSessions(of: day)

        VStack(spacing: 0) {
            // Navigation bar
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("통계")
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Day header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Self.dateFormatter.string(from: day.startedAt)) 시작")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let ended = day.endedAt {
                            Text("\(Self.dateFormatter.string(from: ended)) 종료")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(formatHumanShort(day.totalDuration))
                            .font(.title2.bold())
                    }

                    Divider()

                    // Session list
                    if aggregated.isEmpty {
                        Text("기록된 세션 없음")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(aggregated) { item in
                            HStack {
                                Text(item.name)
                                    .font(.body)
                                    .lineLimit(1)
                                Spacer()
                                Text(formatHumanShort(item.totalDuration))
                                    .font(.body.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Divider()
                        HStack {
                            Text("합계")
                                .font(.body.bold())
                            Spacer()
                            Text(formatHumanShort(day.totalDuration))
                                .font(.body.bold().monospacedDigit())
                        }
                    }
                }
                .padding()
            }
            .frame(maxHeight: 420)
        }
    }
}
