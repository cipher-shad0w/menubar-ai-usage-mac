import SwiftUI

@main
struct menubar_claudeApp: App {
    @StateObject private var viewModel = ClaudeUsageViewModel()

    var body: some Scene {
        MenuBarExtra {
            ClaudeUsageView()
                .environmentObject(viewModel)
        } label: {
            Text("Claude Usage: \(Int(viewModel.fiveHourPercent))%")
        }
        .menuBarExtraStyle(.window)
    }
}
