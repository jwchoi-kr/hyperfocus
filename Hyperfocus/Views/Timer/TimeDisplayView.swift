import SwiftUI

struct TimeDisplayView: View {
    let currentDuration: TimeInterval
    let totalDuration: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            row(label: "Current", duration: currentDuration)
            row(label: "Today", duration: totalDuration)
        }
    }

    private func row(label: String, duration: TimeInterval) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .frame(width: 70, alignment: .leading)
                .foregroundStyle(.secondary)
            Text(formatHHMMSS(duration))
                .monospacedDigit()
        }
        .font(.system(size: 15, weight: .regular, design: .default))
    }
}
