import SwiftUI

struct AverageSummaryView: View {
    @Environment(StatisticsStore.self) private var statsStore

    var body: some View {
        Group {
            if let result = statsStore.recentAverage() {
                if result.sampleSize < 7 {
                    Text("최근 \(result.sampleSize)주기 평균 \(formatHumanShort(result.average))")
                        .font(.headline)
                } else {
                    Text("최근 7주기 평균 \(formatHumanShort(result.average))")
                        .font(.headline)
                }
            } else {
                Text("아직 통계가 없습니다.")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
