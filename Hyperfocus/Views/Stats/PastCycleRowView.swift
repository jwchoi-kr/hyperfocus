import SwiftUI

struct PastCycleRowView: View {
    let cycle: Cycle
    let onSelect: () -> Void

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f
    }()

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.dateFormatter.string(from: cycle.startedAt))
                        .font(.caption)
                    if let ended = cycle.endedAt {
                        Text("→ \(Self.dateFormatter.string(from: ended))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(formatHumanShort(cycle.totalDuration))
                    .font(.caption.monospacedDigit())
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
