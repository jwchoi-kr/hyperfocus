import SwiftUI

enum PopoverScreen {
    case timer
    case stats
    case cycleDetail(Cycle)
}

struct PopoverRoot: View {
    @Environment(TimerStore.self) private var timerStore
    @Environment(StatisticsStore.self) private var statsStore
    @State private var screen: PopoverScreen = .timer

    var body: some View {
        switch screen {
        case .timer:
            TimerScreen(onShowStats: { screen = .stats })
                .frame(width: 300)
        case .stats:
            StatsScreen(
                onBack: { screen = .timer },
                onSelectCycle: { cycle in screen = .cycleDetail(cycle) }
            )
            .frame(width: 300)
        case .cycleDetail(let cycle):
            CycleDetailView(cycle: cycle, onBack: { screen = .stats })
                .frame(width: 300)
        }
    }
}
