import SwiftUI
import AppKit

struct FocusScreen: View {
    @Environment(FocusStore.self) private var focusStore
    @Environment(TimerStore.self) private var timerStore
    let onBack: () -> Void

    @State private var showingAppPicker = false
    @State private var isAddingSite = false
    @State private var newSiteDomain = ""

    private var isBlocking: Bool { timerStore.isRunning }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    statusBadge
                    appsSection
                    Divider()
                    sitesSection
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingAppPicker) {
            AppPickerView(
                alreadyBlocked: Set(focusStore.blockedApps.map(\.bundleIdentifier)),
                onSelect: { app in
                    focusStore.addApp(BlockedApp(
                        id: UUID(),
                        bundleIdentifier: app.bundleIdentifier ?? "",
                        displayName: app.localizedName ?? app.bundleIdentifier ?? "Unknown"
                    ))
                    showingAppPicker = false
                }
            )
        }
    }

    private var navBar: some View {
        ZStack {
            Text("Focus Mode")
                .font(.headline)
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Timer")
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isBlocking ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)
            Text(isBlocking ? "차단 활성" : "차단 비활성")
                .font(.subheadline)
                .foregroundStyle(isBlocking ? .green : .secondary)
        }
    }

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("차단 앱")
                    .font(.headline)
                Spacer()
                Button {
                    showingAppPicker = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .disabled(isBlocking)
            }

            if focusStore.blockedApps.isEmpty {
                Text("없음")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(focusStore.blockedApps) { app in
                    HStack(spacing: 10) {
                        AppIconView(bundleIdentifier: app.bundleIdentifier)
                            .frame(width: 20, height: 20)
                        Text(app.displayName)
                            .font(.subheadline)
                        Spacer()
                        Button {
                            focusStore.removeApp(id: app.id)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .disabled(isBlocking)
                    }
                }
            }
        }
    }

    private var sitesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("차단 사이트")
                .font(.headline)

            if focusStore.blockedSites.isEmpty && !isAddingSite {
                Text("없음")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(focusStore.blockedSites) { site in
                    HStack(spacing: 10) {
                        Image(systemName: "globe")
                            .frame(width: 20, height: 20)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                        Text(site.domain)
                            .font(.subheadline)
                        Spacer()
                        Button {
                            focusStore.removeSite(id: site.id)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .disabled(isBlocking)
                    }
                }
            }

            if isAddingSite {
                HStack {
                    TextField("linkedin.com", text: $newSiteDomain)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { commitNewSite() }
                    Button("취소") {
                        newSiteDomain = ""
                        isAddingSite = false
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                }
            }

            if !isBlocking {
                Button {
                    isAddingSite = true
                } label: {
                    Label("사이트 추가", systemImage: "plus")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .disabled(isAddingSite)
            }
        }
    }

    private func commitNewSite() {
        let domain = newSiteDomain
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
        guard !domain.isEmpty else {
            isAddingSite = false
            return
        }
        focusStore.addSite(BlockedSite(id: UUID(), domain: domain))
        newSiteDomain = ""
        isAddingSite = false
    }
}

private struct AppIconView: View {
    let bundleIdentifier: String

    private var icon: NSImage? {
        if let running = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            return running.icon
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return nil
    }

    var body: some View {
        if let img = icon {
            Image(nsImage: img)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "app.fill")
                .foregroundStyle(.secondary)
        }
    }
}
