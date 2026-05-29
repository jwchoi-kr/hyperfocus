import SwiftUI

struct StatsScreen: View {
    let onBack: () -> Void
    let onSelectDay: (Day) -> Void

    var body: some View {
        VStack(spacing: 0) {
            PopoverNavBar(title: "Stats", backLabel: "Timer", onBack: onBack)
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
