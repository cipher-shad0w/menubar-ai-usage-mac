import SwiftUI

struct ClaudeUsageView: View {
    @EnvironmentObject var viewModel: ClaudeUsageViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text("Claude Usage Monitor")
                .font(.headline)
                .padding(.top, 8)

            Divider()

            // Content
            if viewModel.isLoading && viewModel.usageData == nil {
                loadingView
            } else if let error = viewModel.error {
                errorView(error: error)
            } else {
                usageContentView
            }

            Divider()

            // Footer
            footerView
        }
        .padding()
        .frame(width: 320)
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading usage data...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 20)
    }

    private func errorView(error: ClaudeUsageError) -> some View {
        VStack(spacing: 16) {
            // Error icon
            Image(systemName: error.iconName)
                .font(.system(size: 48))
                .foregroundColor(iconColorForError(error))

            // Error title
            Text(error.title)
                .font(.headline)
                .fontWeight(.bold)

            // Error message
            Text(error.message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Show browser-specific buttons for authentication errors
            if let installedBrowsers = error.installedBrowsers, !installedBrowsers.isEmpty {
                browserButtons(for: installedBrowsers)
            }

            // Action buttons
            VStack(spacing: 8) {
                // Suggested action button if available
                if let suggestedAction = error.suggestedAction {
                    Button(action: {
                        openSuggestedActionURL(for: error)
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                            Text(suggestedAction)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                // Retry button
                Button(action: {
                    viewModel.refresh()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
    }

    /// Browser buttons for authentication error
    private func browserButtons(for browsers: [SupportedBrowser]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Open browser:")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(browsers, id: \.self) { browser in
                Button(action: {
                    openBrowser(browser)
                }) {
                    HStack {
                        Image(systemName: "globe")
                        Text(browser.displayName)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    /// Open a specific browser to Claude.ai
    private func openBrowser(_ browser: SupportedBrowser) {
        // Try to open Claude.ai directly in the specific browser
        if let url = URL(string: "https://claude.ai") {
            let configuration = NSWorkspace.OpenConfiguration()

            // Try to find the browser app
            if let appURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: browser.bundleIdentifier)
            {
                NSWorkspace.shared.open(
                    [url], withApplicationAt: appURL, configuration: configuration
                ) { _, error in
                    if error != nil {
                        // Fallback to default browser
                        NSWorkspace.shared.open(url)
                    }
                }
            } else {
                // Fallback to default browser
                NSWorkspace.shared.open(url)
            }
        }
    }

    /// Get color for error icon
    private func iconColorForError(_ error: ClaudeUsageError) -> Color {
        switch error {
        case .cookieAuthenticationFailed:
            return .orange
        case .uvNotFound:
            return .yellow
        case .networkError:
            return .blue
        case .forbidden:
            return .red
        case .scriptExecutionFailed, .parseError:
            return .purple
        case .unknown:
            return .gray
        }
    }

    /// Open URL for suggested action
    private func openSuggestedActionURL(for error: ClaudeUsageError) {
        switch error {
        case .cookieAuthenticationFailed(let installedBrowsers, let allSupportedBrowsers):
            if installedBrowsers.isEmpty {
                // Open first supported browser's download page
                if let firstBrowser = allSupportedBrowsers.first,
                    let url = URL(string: firstBrowser.downloadURL)
                {
                    NSWorkspace.shared.open(url)
                }
            } else if installedBrowsers.count == 1 {
                // Open the single installed browser
                openBrowser(installedBrowsers[0])
            } else {
                // Open default browser
                if let url = URL(string: "https://claude.ai") {
                    NSWorkspace.shared.open(url)
                }
            }
        case .uvNotFound:
            if let url = URL(string: "https://docs.astral.sh/uv/getting-started/installation/") {
                NSWorkspace.shared.open(url)
            }
        case .forbidden:
            if let url = URL(string: "https://claude.ai") {
                NSWorkspace.shared.open(url)
            }
        default:
            break
        }
    }

    private var usageContentView: some View {
        VStack(spacing: 16) {
            // 5-Hour Window
            usageWindowCard(
                title: "5-Hour Window",
                percent: viewModel.fiveHourPercent,
                status: viewModel.fiveHourStatus,
                window: viewModel.fiveHourWindow
            )

            // 7-Day Window
            usageWindowCard(
                title: "7-Day Window",
                percent: viewModel.sevenDayPercent,
                status: viewModel.sevenDayStatus,
                window: viewModel.sevenDayWindow
            )

            // Alert for exhausted state
            if viewModel.isExhausted {
                exhaustedAlert
            }
        }
    }

    private func usageWindowCard(
        title: String,
        percent: Double,
        status: UsageStatus,
        window: UsageWindow?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                statusBadge(status: status)
            }

            // Progress Bar
            ProgressView(value: percent, total: 100)
                .tint(colorForStatus(status))

            // Details
            HStack {
                Text(String(format: "%.1f%%", percent))
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                if let window = window {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Resets in")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(window.formattedTimeUntilReset)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }

            // Additional info
            if let window = window, let used = window.used, let limit = window.limit {
                Text("\(used) / \(limit) requests used")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.black)
        )
    }

    private func statusBadge(status: UsageStatus) -> some View {
        Text(status.description)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(colorForStatus(status).opacity(0.2))
            )
            .foregroundColor(colorForStatus(status))
    }

    private var exhaustedAlert: some View {
        HStack(spacing: 12) {
            Image(systemName: "pause.circle.fill")
                .font(.title2)
                .foregroundColor(.red)
            VStack(alignment: .leading, spacing: 4) {
                Text("Limit Reached")
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text("7-day window exhausted. Please wait for reset.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
        )
    }

    private var footerView: some View {
        HStack {
            if let lastUpdated = viewModel.lastUpdated {
                Text("Updated: \(lastUpdated, style: .relative)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { viewModel.refresh() }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.caption)
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.isLoading)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
    }

    // MARK: - Helper Methods

    private func colorForStatus(_ status: UsageStatus) -> Color {
        switch status {
        case .ready: return .green
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .exhausted: return .red
        }
    }
}

// MARK: - Preview

#Preview {
    ClaudeUsageView()
        .environmentObject(ClaudeUsageViewModel())
}
