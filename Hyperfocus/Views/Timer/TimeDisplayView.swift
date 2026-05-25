import SwiftUI

struct TimeDisplayView: View {
    let label: String
    let duration: TimeInterval
    let large: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(formatHHMMSS(duration))
                .font(large ? .system(size: 44, weight: .thin, design: .monospaced) : .title2.monospacedDigit())
                .monospacedDigit()
        }
    }
}
