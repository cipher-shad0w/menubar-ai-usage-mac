//
//  ClaudeUsageViewModel.swift
//  menubar-claude
//
//  ViewModel for managing Claude usage data
//

import Foundation
import Combine
import OSLog
import ServiceManagement

/// ViewModel for Claude usage monitoring
@MainActor
class ClaudeUsageViewModel: ObservableObject {
    // MARK: - Constants

    private enum Config {
        /// Default interval between auto-refresh checks (in seconds)
        static let defaultRefreshInterval: TimeInterval = 30

        /// Timeout for UV process execution (in seconds)
        static let uvProcessTimeout: TimeInterval = 10

        /// Percentage threshold for "low" usage status
        static let lowUsageThreshold: Double = 50.0

        /// Percentage threshold for "high" usage status (7-day window priority)
        static let highUsageThreshold: Double = 80.0

        /// Percentage threshold for "critical" usage status
        static let criticalUsageThreshold: Double = 95.0

        /// Maximum usage percentage (exhausted)
        static let exhaustedThreshold: Double = 100.0
    }

    // MARK: - Logger
    private let logger = Logger(subsystem: "com.menubar.claude", category: "ClaudeUsageViewModel")

    // MARK: - Published Properties

    /// Full usage response from API
    @Published private(set) var usageData: ClaudeUsageResponse?

    /// 5-hour window utilization percentage (0-100)
    @Published private(set) var fiveHourPercent: Double = 0.0

    /// 7-day window utilization percentage (0-100)
    @Published private(set) var sevenDayPercent: Double = 0.0

    /// 5-hour window data
    @Published private(set) var fiveHourWindow: UsageWindow?

    /// 7-day window data
    @Published private(set) var sevenDayWindow: UsageWindow?

    /// Loading state
    @Published private(set) var isLoading: Bool = false

    /// Structured error
    @Published private(set) var error: ClaudeUsageError?

    /// Last update timestamp
    @Published private(set) var lastUpdated: Date?

    /// Launch at login state
    @Published var launchAtLogin: Bool = false

    // MARK: - Computed Properties

    /// Status for 5-hour window
    var fiveHourStatus: UsageStatus {
        UsageStatus(utilization: fiveHourPercent)
    }

    /// Status for 7-day window
    var sevenDayStatus: UsageStatus {
        UsageStatus(utilization: sevenDayPercent)
    }

    /// Primary window to display (7-day if >80%, otherwise 5-hour)
    var primaryWindow: (percent: Double, name: String, window: UsageWindow?) {
        if sevenDayPercent >= Config.highUsageThreshold {
            return (sevenDayPercent, "7-Day", sevenDayWindow)
        } else {
            return (fiveHourPercent, "5-Hour", fiveHourWindow)
        }
    }

    /// Whether the service is exhausted (7-day at 100%)
    var isExhausted: Bool {
        sevenDayPercent >= Config.exhaustedThreshold
    }

    // MARK: - Private Properties
    private let pythonScriptPath: String
    private var timer: Timer?

    // MARK: - Initialization

    init(pythonScriptPath: String? = nil) {
        // Default to finding claude.py in app bundle or development environment
        if let providedPath = pythonScriptPath {
            self.pythonScriptPath = providedPath
        } else if let bundlePath = Bundle.main.path(forResource: "claude", ofType: "py") {
            // Production: Script is bundled in app resources
            self.pythonScriptPath = bundlePath
        } else {
            // Development: Look for script relative to project
            let fileManager = FileManager.default
            let currentPath = fileManager.currentDirectoryPath
            let devPath = URL(fileURLWithPath: currentPath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("src")
                .appendingPathComponent("claude.py")
            self.pythonScriptPath = devPath.path
        }

        logger.info("Initialized ClaudeUsageViewModel with script path: \(self.pythonScriptPath)")

        // Check initial launch at login state
        self.launchAtLogin = Self.checkLaunchAtLoginStatus()

        // Fetch data immediately on init and start auto-refresh
        Task { @MainActor in
            await self.fetchUsage()
            self.startAutoRefresh(interval: Config.defaultRefreshInterval)
        }
    }

    // MARK: - Public Methods

    /// Fetch usage data from claude.py script
    func fetchUsage() async {
        logger.info("Starting fetchUsage()")

        isLoading = true
        error = nil

        do {
            let output = try await runPythonScript()
            logger.debug("Received output from Python script: \(output.prefix(200))...")

            let data = try parseJSON(from: output)
            updateStoredValues(with: data)

            lastUpdated = Date()
            logger.info("Successfully fetched usage data - 5h: \(self.fiveHourPercent)%, 7d: \(self.sevenDayPercent)%")

        } catch let usageError as ClaudeUsageError {
            logger.error("Structured error: \(usageError.title) - \(usageError.message)")
            self.error = usageError
        } catch let unexpectedError {
            logger.error("Unexpected error: \(unexpectedError.localizedDescription)")
            self.error = .unknown(message: unexpectedError.localizedDescription)
        }

        isLoading = false
    }

    /// Start auto-refresh timer
    func startAutoRefresh(interval: TimeInterval = 300) {
        logger.info("Starting auto-refresh with interval: \(interval)s")

        stopAutoRefresh()

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchUsage()
            }
        }
    }

    /// Stop auto-refresh timer
    func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
        logger.info("Stopped auto-refresh")
    }

    /// Manually refresh data
    func refresh() {
        logger.info("Manual refresh triggered")
        Task {
            await fetchUsage()
        }
    }

    // MARK: - Private Methods

    /// Locates the UV package manager executable using a multi-stage search strategy.
    ///
    /// UV (https://docs.astral.sh/uv/) is a fast Python package installer required
    /// to execute the Claude API client script.
    ///
    /// - Returns: Absolute path to the `uv` executable, or `nil` if not found
    ///
    /// ## Search Strategy
    /// 1. **Fast Path**: Checks common installation locations:
    ///    - `~/.local/bin/uv` (pipx/cargo install)
    ///    - `/usr/local/bin/uv` (manual install)
    ///    - `~/.cargo/bin/uv` (Rust cargo)
    ///    - `/opt/homebrew/bin/uv` (Homebrew on Apple Silicon)
    ///
    /// 2. **Fallback**: Executes login shell (`zsh -l -c "which uv"`) to respect
    ///    user's PATH configuration (e.g., custom shell profiles)
    ///
    /// ## Performance
    /// - Fast path: ~1-5ms (file existence checks)
    /// - Fallback: ~100-300ms (shell process overhead)
    private func findUvPath() -> String? {
        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser.path

        // Step 1: Check common uv installation locations (fast)
        let possiblePaths = [
            "\(homeDir)/.local/bin/uv",
            "/usr/local/bin/uv",
            "\(homeDir)/.cargo/bin/uv",
            "/opt/homebrew/bin/uv"
        ]

        for path in possiblePaths {
            if fileManager.fileExists(atPath: path) {
                logger.debug("Found uv at standard location: \(path)")
                return path
            }
        }

        // Step 2: Fallback to login shell (slower but respects user's PATH)
        logger.debug("uv not found in standard locations, trying login shell...")

        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "which uv"]
        process.standardOutput = pipe
        process.standardError = Pipe() // Discard errors

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let uvPath = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !uvPath.isEmpty && fileManager.fileExists(atPath: uvPath) {
                        logger.debug("Found uv via login shell: \(uvPath)")
                        return uvPath
                    }
                }
            }
        } catch {
            logger.warning("Failed to execute login shell: \(error.localizedDescription)")
        }

        logger.warning("Could not find uv executable")
        return nil
    }

    /// Executes the Python script to fetch Claude API usage data.
    ///
    /// This method spawns a subprocess to run the `claude.py` script using the UV
    /// package manager. The script authenticates using browser cookies and returns
    /// JSON-formatted usage data.
    ///
    /// - Returns: Raw stdout from the Python script (JSON + optional text)
    /// - Throws: `ClaudeUsageError` for various failure conditions:
    ///   - `.uvNotFound`: UV executable not located on system
    ///   - `.scriptExecutionFailed`: Python runtime errors
    ///   - `.cookieAuthenticationFailed`: No valid Claude session found
    ///   - `.networkError`: API connection issues
    ///   - `.forbidden`: 403 response from Claude API
    ///
    /// ## Process Configuration
    /// - **Executable**: `uv run python <script_path>`
    /// - **Working Directory**: Parent directory of `claude.py` (for relative imports)
    /// - **Timeout**: None (Python script has internal 10s timeout)
    ///
    /// ## Error Handling
    /// Parses stderr to identify specific error types using `ClaudeUsageError.parse()`.
    /// Exit status != 0 triggers structured error parsing.
    private func runPythonScript() async throws -> String {
        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()

        // Set working directory to script directory (so it can find common.py)
        let scriptDir = URL(fileURLWithPath: self.pythonScriptPath)
            .deletingLastPathComponent()
        process.currentDirectoryURL = scriptDir

        process.standardOutput = pipe
        process.standardError = errorPipe

        // Find uv executable
        guard let uvPath = findUvPath() else {
            throw ClaudeUsageError.uvNotFound
        }

        // Use uv to run Python script
        process.executableURL = URL(fileURLWithPath: uvPath)
        process.arguments = ["run", "python", self.pythonScriptPath]

        logger.debug("Executing: \(uvPath) run python \(self.pythonScriptPath)")
        logger.debug("Working directory: \(scriptDir.path)")

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            logger.error("Python script failed with status \(process.terminationStatus): \(errorOutput)")
            // Parse the error to get structured error type
            throw ClaudeUsageError.parse(from: errorOutput)
        }

        guard let output = String(data: data, encoding: .utf8) else {
            throw ClaudeUsageError.parseError(message: "Failed to decode script output")
        }

        return output
    }

    /// Parses JSON response from Python script, handling mixed output.
    ///
    /// The Python script may output both structured JSON and human-readable text.
    /// This method extracts only the JSON object by counting braces to identify
    /// the complete JSON structure, ignoring any additional text before or after.
    ///
    /// - Parameter output: Raw output string from Python script execution
    /// - Returns: Parsed `ClaudeUsageResponse` containing usage data
    /// - Throws: `ClaudeUsageError.parseError` if JSON extraction or decoding fails
    ///
    /// ## Algorithm
    /// 1. Splits output into lines
    /// 2. Tracks brace count to identify JSON object boundaries
    /// 3. Extracts lines between opening `{` and matching closing `}`
    /// 4. Decodes extracted JSON into `ClaudeUsageResponse`
    private func parseJSON(from output: String) throws -> ClaudeUsageResponse {
        // The script outputs JSON followed by separator and human-readable format
        // We need to extract just the JSON part
        let lines = output.components(separatedBy: "\n")
        var jsonLines: [String] = []
        var inJSON = false
        var braceCount = 0

        for line in lines {
            // Count braces to track JSON object
            for char in line {
                if char == "{" {
                    if !inJSON { inJSON = true }
                    braceCount += 1
                } else if char == "}" {
                    braceCount -= 1
                }
            }

            if inJSON {
                jsonLines.append(line)
            }

            // JSON object complete
            if inJSON && braceCount == 0 {
                break
            }
        }

        let jsonString = jsonLines.joined(separator: "\n")
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw ClaudeUsageError.parseError(message: "Failed to convert JSON string to data")
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(ClaudeUsageResponse.self, from: jsonData)
        } catch {
            throw ClaudeUsageError.parseError(message: "Failed to decode JSON: \(error.localizedDescription)")
        }
    }

    /// Update stored values with new data
    private func updateStoredValues(with data: ClaudeUsageResponse) {
        usageData = data

        // Store 5-hour window data
        if let fiveHour = data.fiveHour {
            fiveHourWindow = fiveHour
            fiveHourPercent = fiveHour.utilization
            logger.debug("Updated 5-hour window: \(fiveHour.utilization)%")
        } else {
            fiveHourWindow = nil
            fiveHourPercent = 0.0
            logger.warning("No 5-hour window data available")
        }

        // Store 7-day window data
        if let sevenDay = data.sevenDay {
            sevenDayWindow = sevenDay
            sevenDayPercent = sevenDay.utilization
            logger.debug("Updated 7-day window: \(sevenDay.utilization)%")
        } else {
            sevenDayWindow = nil
            sevenDayPercent = 0.0
            logger.warning("No 7-day window data available")
        }

        // Log status
        logger.info("Storage updated - 5h: \(self.fiveHourPercent)% (\(self.fiveHourStatus.description)), 7d: \(self.sevenDayPercent)% (\(self.sevenDayStatus.description))")
    }

    // MARK: - Launch at Login

    /// Check if the app is set to launch at login
    private static func checkLaunchAtLoginStatus() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }

    /// Toggle launch at login setting
    func toggleLaunchAtLogin() {
        do {
            if launchAtLogin {
                // Disable launch at login
                try SMAppService.mainApp.unregister()
                launchAtLogin = false
                logger.info("Disabled launch at login")
            } else {
                // Enable launch at login
                try SMAppService.mainApp.register()
                launchAtLogin = true
                logger.info("Enabled launch at login")
            }
        } catch {
            logger.error("Failed to toggle launch at login: \(error.localizedDescription)")
        }
    }
}
