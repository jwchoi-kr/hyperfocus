import SwiftUI

struct StatsScreen: View {
    let onBack: () -> Void
    let onSelectDay: (Day) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Navigation bar: back button left, "Stats" centered via ZStack
            ZStack {
                Text("Stats")
                    .font(.headline)
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Timer")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader("Today")
                    CurrentDayCardView()

                    sectionHeader("This Week")
                        .padding(.top, 12)
                    WeeklyBarChartView()

                    sectionHeader("This Month")
                        .padding(.top, 12)
                    MonthlyCalendarView(onSelectDay: onSelectDay)
                }
                .padding()
            }
            .frame(maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.bold())
            .foregroundStyle(.secondary)
    }

}
