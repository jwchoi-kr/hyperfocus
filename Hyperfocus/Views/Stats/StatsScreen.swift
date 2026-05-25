import SwiftUI

struct StatsScreen: View {
    @Environment(StatisticsStore.self) private var statsStore
    let onBack: () -> Void
    let onSelectDay: (Day) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Navigation bar
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("타이머")
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                Spacer()
                Text("통계")
                    .font(.headline)
                Spacer()
                    .frame(width: 60)  // balance back button width
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    AverageSummaryView()
                    CurrentDayCardView()

                    if !statsStore.pastDays.isEmpty {
                        Text("지난 날")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(statsStore.pastDays) { day in
                            PastDayRowView(day: day, onSelect: { onSelectDay(day) })
                            Divider()
                        }
                    }
                }
                .padding()
            }
            .frame(maxHeight: 420)
        }
    }
}
