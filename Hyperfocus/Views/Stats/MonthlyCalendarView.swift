import SwiftUI

// MARK: - Data model

fileprivate struct CalendarCell: Identifiable {
    let id: Int
    let date: Date?
    let day: Day?
    let isPastDay: Bool
    let isToday: Bool
}

// MARK: - Main view

struct MonthlyCalendarView: View {
    @Environment(TimerStore.self) private var timerStore
    @Environment(StatisticsStore.self) private var statsStore
    let onSelectDay: (Day) -> Void

    @State private var displayedMonthStart: Date = {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
    }()

    private let calendar = Calendar.current
    private let weekdayHeaders = ["S", "M", "T", "W", "T", "F", "S"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    /// Dates before 6am belong to the previous calendar day (6am rollover boundary).
    private func appDayStart(for date: Date) -> Date {
        let hour = calendar.component(.hour, from: date)
        let midnight = calendar.startOfDay(for: date)
        return hour < 6 ? calendar.date(byAdding: .day, value: -1, to: midnight)! : midnight
    }

    private var dayLookup: [Date: (day: Day, isPast: Bool)] {
        var lookup: [Date: (day: Day, isPast: Bool)] = [:]
        lookup[appDayStart(for: timerStore.currentDay.startedAt)] = (timerStore.currentDay, false)
        for pastDay in statsStore.pastDays {
            lookup[appDayStart(for: pastDay.startedAt)] = (pastDay, true)
        }
        return lookup
    }

    private var cells: [CalendarCell] {
        let daysInMonth = calendar.range(of: .day, in: .month, for: displayedMonthStart)!.count
        // Calendar.weekday: 1=Sun … 7=Sat → subtract 1 for 0-based Sunday offset
        let leadingPadding = calendar.component(.weekday, from: displayedMonthStart) - 1
        let todayStart = appDayStart(for: Date())
        let lookup = dayLookup

        var result: [CalendarCell] = []

        for i in 0..<leadingPadding {
            result.append(CalendarCell(id: -(leadingPadding - i), date: nil, day: nil, isPastDay: false, isToday: false))
        }

        for dayNum in 1...daysInMonth {
            let date = calendar.date(byAdding: .day, value: dayNum - 1, to: displayedMonthStart)!
            let dateStart = calendar.startOfDay(for: date)
            let match = lookup[dateStart]
            result.append(CalendarCell(
                id: dayNum,
                date: date,
                day: match?.day,
                isPastDay: match?.isPast ?? false,
                isToday: dateStart == todayStart
            ))
        }

        let remainder = result.count % 7
        if remainder > 0 {
            for i in 0..<(7 - remainder) {
                result.append(CalendarCell(id: daysInMonth + i + 1, date: nil, day: nil, isPastDay: false, isToday: false))
            }
        }

        return result
    }

    var body: some View {
        let allCells = cells
        VStack(spacing: 6) {
            HStack {
                Button {
                    displayedMonthStart = calendar.date(byAdding: .month, value: -1, to: displayedMonthStart)!
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    let cal = Calendar.current
                    displayedMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
                } label: {
                    Text(Self.monthFormatter.string(from: displayedMonthStart))
                        .font(.footnote.bold())
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    displayedMonthStart = calendar.date(byAdding: .month, value: 1, to: displayedMonthStart)!
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 0) {
                ForEach(Array(weekdayHeaders.enumerated()), id: \.offset) { _, label in
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(allCells) { cell in
                    if let date = cell.date {
                        CalendarDayCellView(
                            date: date,
                            duration: cell.day?.totalDuration ?? 0,
                            isPastDay: cell.isPastDay,
                            isToday: cell.isToday,
                            onTap: {
                                if cell.isPastDay, let day = cell.day {
                                    onSelectDay(day)
                                }
                            }
                        )
                    } else {
                        Color.clear.frame(height: 48)
                    }
                }
            }
        }
    }
}

// MARK: - Day cell

private struct CalendarDayCellView: View {
    let date: Date
    let duration: TimeInterval
    let isPastDay: Bool
    let isToday: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    private var dateNumber: Int {
        Calendar.current.component(.day, from: date)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(dateNumber)")
                        .font(.system(size: 10))
                        .foregroundStyle(isToday ? Color.accentColor : .secondary)

                    if duration > 0 {
                        Text(formatHHMM(duration))
                            .font(.system(size: 9).monospacedDigit())
                            .foregroundStyle(isToday ? Color.accentColor : .primary)
                    }
                }
                .padding(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                if isHovered {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.07))
                }
            }
            .frame(height: 48)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                (isPastDay ? NSCursor.pointingHand : NSCursor.arrow).push()
            } else {
                NSCursor.pop()
            }
        }
    }

    private var backgroundColor: Color {
        if isToday {
            return Color.accentColor.opacity(0.15)
        } else if duration > 0 {
            return Color.secondary.opacity(0.08)
        } else {
            return Color.secondary.opacity(0.04)
        }
    }
}
