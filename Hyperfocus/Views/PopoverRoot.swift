import SwiftUI

enum PopoverScreen {
    case timer
    case stats
    case dayDetail(Day)
    case focus
}

struct PopoverRoot: View {
    @Environment(TimerStore.self) private var timerStore
    @Environment(StatisticsStore.self) private var statsStore
    @State private var screen: PopoverScreen = .timer

    var body: some View {
        switch screen {
        case .timer:
            TimerScreen(
                onShowStats: { screen = .stats },
                onShowFocus: { screen = .focus }
            )
            .frame(width: 300)
        case .stats:
            StatsScreen(
                onBack: { screen = .timer },
                onSelectDay: { day in screen = .dayDetail(day) }
            )
            .frame(width: 420, height: 820)
        case .dayDetail(let day):
            DayDetailView(day: day, onBack: { screen = .stats })
                .frame(width: 420, height: 820)
        case .focus:
            FocusScreen(onBack: { screen = .timer })
                .frame(width: 300, height: 420)
        }
    }
}
