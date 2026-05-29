import SwiftUI
import AppKit

struct FocusScreen: View {
    @Environment(FocusStore.self) private var focusStore
    @Environment(TimerStore.self) private var timerStore
    let onBack: () -> Void

    @State private var showingAppPicker = false
    @State private var isAddingSite = false
    @State private var newSiteDomain = ""
    @FocusState private var isSiteFieldFocused: Bool

    private var isBlocking: Bool { timerStore.isRunning }

    var body: some View {
        if showingAppPicker {
            AppPickerView(
                alreadyBlocked: Set(focusStore.blockedApps.map(\.bundleIdentifier)),
                onSelect: { app in
                    focusStore.addApp(BlockedApp(
                        id: UUID(),
                        bundleIdentifier: app.bundleIdentifier ?? "",
                        displayName: app.localizedName ?? app.bundleIdentifier ?? "Unknown"
                    ))
                    showingAppPicker = false
                },
                onCancel: { showingAppPicker = false }
            )
        } else {
            VStack(spacing: 0) {
                PopoverNavBar(title: "Focus", backLabel: "Timer", onBack: onBack)
                Divider()
                VStack(alignment: .leading, spacing: 20) {
                    statusBadge
                    macOSFocusSection
                    Divider()
                    appsSection
                    Divider()
                    sitesSection
                }
                .padding()
                Spacer()
            }
        }
    }

    private var macOSFocusSection: some View {
        Toggle(isOn: Binding(
            get: { focusStore.isMacOSFocusEnabled },
            set: { focusStore.setMacOSFocusEnabled($0) }
        )) {
            Text("macOS Focus")
                .font(.headline)
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isBlocking ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)
            Text(isBlocking ? "Blocking Active" : "Inactive")
                .font(.subheadline)
                .foregroundStyle(isBlocking ? .green : .secondary)
        }
    }

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Blocked Apps")
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
                Text("None")
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
            Text("Blocked Sites")
                .font(.headline)

            if focusStore.blockedSites.isEmpty && !isAddingSite {
                Text("None")
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
                        .focused($isSiteFieldFocused)
                        .onSubmit { commitNewSite() }
                        .onKeyPress(.escape) {
                            newSiteDomain = ""
                            isAddingSite = false
                            return .handled
                        }
                    Button("Cancel") {
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
                    isSiteFieldFocused = true
                } label: {
                    Label("Add Site", systemImage: "plus")
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
    @State private var resolvedIcon: NSImage?

    var body: some View {
        Group {
            if let img = resolvedIcon {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "app.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if let running = NSWorkspace.shared.runningApplications
                .first(where: { $0.bundleIdentifier == bundleIdentifier }) {
                resolvedIcon = running.icon
            } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                resolvedIcon = NSWorkspace.shared.icon(forFile: url.path)
            }
        }
    }
}
