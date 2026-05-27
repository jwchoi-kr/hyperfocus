import SwiftUI
import Charts

struct WeeklyBarChartView: View {
    @Environment(TimerStore.self) private var timerStore
    @Environment(StatisticsStore.self) private var statsStore

    private struct DayBar: Identifiable {
        let id: Int
        let label: String   // "Mon", "Tue", ...
        let dateNumber: Int // day of month
        let hours: Double
        let isCurrentDay: Bool  // 달력 기준 "오늘"이 아닌 새벽 6시 경계 기준 현재 하루
    }

    private var barData: [DayBar] {
        let calendar = Calendar.current
        let today = Date()

        // Monday of the current week (weekday: 1=Sun, 2=Mon, ..., 7=Sat)
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!
        let startOfMonday = calendar.startOfDay(for: monday)

        let weekdayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let allDays = [timerStore.currentDay] + statsStore.pastDays

        // 새벽 6시 기준으로 하루가 나뉘므로, 달력 기준 "오늘"이 아닌
        // currentDay.startedAt이 속한 날짜를 현재 하루로 간주한다.
        let currentDayStart = timerStore.currentDay.startedAt

        return (0..<7).map { offset in
            let targetDate = calendar.date(byAdding: .day, value: offset, to: startOfMonday)!
            let isCurrentDay = calendar.isDate(currentDayStart, inSameDayAs: targetDate)

            let matchingDay = allDays.first { day in
                calendar.isDate(day.startedAt, inSameDayAs: targetDate)
            }

            let hours: Double
            if isCurrentDay {
                hours = timerStore.totalDuration / 3600
            } else {
                hours = (matchingDay?.totalDuration ?? 0) / 3600
            }

            let dayNumber = calendar.component(.day, from: targetDate)
            return DayBar(id: offset, label: weekdayLabels[offset], dateNumber: dayNumber, hours: hours, isCurrentDay: isCurrentDay)
        }
    }

    var body: some View {
        let data = barData
        let labels = data.map(\.label)
        Chart(data) { item in
            BarMark(
                x: .value("Day", item.label),
                y: .value("Hours", item.hours)
            )
            .foregroundStyle(item.isCurrentDay ? Color.accentColor : Color.secondary.opacity(0.45))
            .cornerRadius(3)
        }
        .chartXScale(domain: labels)
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let h = value.as(Double.self) {
                        Text(String(format: "%.0fh", h))
                            .font(.system(size: 10))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                if let label = value.as(String.self),
                   let bar = data.first(where: { $0.label == label }) {
                    AxisValueLabel {
                        VStack(spacing: 1) {
                            Text(bar.label)
                                .font(.system(size: 11))
                            Text("\(bar.dateNumber)")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(height: 130)
    }
}
