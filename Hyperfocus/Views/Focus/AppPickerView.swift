import SwiftUI
import AppKit

struct AppPickerView: View {
    let alreadyBlocked: Set<String>
    let onSelect: (NSRunningApplication) -> Void

    @Environment(\.dismiss) private var dismiss

    private var availableApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .filter { app in
                guard let bundle = app.bundleIdentifier else { return false }
                return !alreadyBlocked.contains(bundle)
            }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("차단할 앱 선택")
                    .font(.headline)
                Spacer()
                Button("취소") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            Divider()

            if availableApps.isEmpty {
                Text("추가 가능한 앱이 없습니다")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(availableApps, id: \.bundleIdentifier) { app in
                            Button {
                                onSelect(app)
                            } label: {
                                HStack(spacing: 10) {
                                    if let icon = app.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 24, height: 24)
                                    }
                                    Text(app.localizedName ?? app.bundleIdentifier ?? "Unknown")
                                        .font(.subheadline)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 7)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
            }
        }
        .frame(width: 280, height: 380)
    }
}
