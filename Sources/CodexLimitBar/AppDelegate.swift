import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let client = CodexRateLimitClient()
    private var statusItem: NSStatusItem?
    private var refreshTimer: Timer?
    private var latest: CachedRateLimits?
    private var latestError: String?
    private var isRefreshing = false
    private var displayMode = MenuBarLimitMode.saved

    private let cacheURL: URL = {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CodexLimitBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("rate-limits.json")
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        latest = loadCache()
        installStatusItem()
        rebuildMenu()
        scheduleRefreshTimer()
        refreshNow(nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(powerStateDidChange),
            name: Notification.Name("NSProcessInfoPowerStateDidChange"),
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = codexMenuIcon()
        item.button?.imagePosition = .imageLeading
        statusItem = item
        updateStatusTitle()
    }

    @objc private func powerStateDidChange() {
        scheduleRefreshTimer()
        rebuildMenu()
    }

    @objc private func timerFired() {
        refreshNow(nil)
    }

    @objc private func refreshNow(_ sender: Any?) {
        guard !isRefreshing else { return }
        isRefreshing = true
        latestError = nil
        updateStatusTitle()
        rebuildMenu()

        Task {
            do {
                let result = try await client.fetch()
                let cached = CachedRateLimits(fetchedAt: Date(), result: result)
                latest = cached
                latestError = nil
                saveCache(cached)
            } catch {
                latestError = error.localizedDescription
            }
            isRefreshing = false
            updateStatusTitle()
            rebuildMenu()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func showFiveHourLimit() {
        setDisplayMode(.fiveHour)
    }

    @objc private func showWeeklyLimit() {
        setDisplayMode(.weekly)
    }

    private func setDisplayMode(_ mode: MenuBarLimitMode) {
        guard displayMode != mode else { return }
        displayMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: MenuBarLimitMode.defaultsKey)
        updateStatusTitle()
        rebuildMenu()
    }

    private func scheduleRefreshTimer() {
        refreshTimer?.invalidate()
        let interval = PowerState.refreshInterval
        let timer = Timer.scheduledTimer(
            timeInterval: interval,
            target: self,
            selector: #selector(timerFired),
            userInfo: nil,
            repeats: true
        )
        timer.tolerance = interval * 0.2
        refreshTimer = timer
    }

    private func updateStatusTitle() {
        statusItem?.button?.title = menuBarTitle
    }

    private var menuBarTitle: String {
        MenuBarTitleFormatter(displayMode: displayMode)
            .title(
                snapshot: latest?.result.rateLimits,
                isInitialRefresh: isRefreshing && latest == nil,
                latestError: latestError
            )
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let summary = NSMenuItem(title: primarySummary, action: nil, keyEquivalent: "")
        summary.isEnabled = false
        menu.addItem(summary)

        let reset = NSMenuItem(title: resetSummary, action: nil, keyEquivalent: "")
        reset.isEnabled = false
        menu.addItem(reset)

        let weekly = NSMenuItem(title: weeklySummary, action: nil, keyEquivalent: "")
        weekly.isEnabled = false
        menu.addItem(weekly)

        if let sparkSummary = sparkSummary {
            let spark = NSMenuItem(title: sparkSummary, action: nil, keyEquivalent: "")
            spark.isEnabled = false
            menu.addItem(spark)
        }

        let credits = NSMenuItem(title: creditsSummary, action: nil, keyEquivalent: "")
        credits.isEnabled = false
        menu.addItem(credits)

        let freshness = NSMenuItem(title: freshnessSummary, action: nil, keyEquivalent: "")
        freshness.isEnabled = false
        menu.addItem(freshness)

        if let latestError {
            let errorItem = NSMenuItem(title: "Error: \(latestError)", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            menu.addItem(errorItem)
        }

        menu.addItem(.separator())

        let modeHeader = NSMenuItem(title: "Displayed Limit", action: nil, keyEquivalent: "")
        modeHeader.isEnabled = false
        menu.addItem(modeHeader)

        let fiveHourMode = NSMenuItem(title: MenuBarLimitMode.fiveHour.title, action: #selector(showFiveHourLimit), keyEquivalent: "")
        fiveHourMode.target = self
        fiveHourMode.state = displayMode == .fiveHour ? .on : .off
        menu.addItem(fiveHourMode)

        let weeklyMode = NSMenuItem(title: MenuBarLimitMode.weekly.title, action: #selector(showWeeklyLimit), keyEquivalent: "")
        weeklyMode.target = self
        weeklyMode.state = displayMode == .weekly ? .on : .off
        menu.addItem(weeklyMode)

        menu.addItem(.separator())

        let refresh = NSMenuItem(
            title: isRefreshing ? "Refreshing..." : "Refresh Now",
            action: #selector(refreshNow(_:)),
            keyEquivalent: "r"
        )
        refresh.target = self
        refresh.isEnabled = !isRefreshing
        menu.addItem(refresh)

        let power = NSMenuItem(
            title: "Auto refresh: \(formatDuration(PowerState.refreshInterval)) (\(PowerState.description))",
            action: nil,
            keyEquivalent: ""
        )
        power.isEnabled = false
        menu.addItem(power)

        let quitItem = NSMenuItem(title: "Quit CodexLimitBar", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    private func codexMenuIcon() -> NSImage? {
        if let icon = installedOpenAIAppIcon() {
            return icon
        }

        for symbolName in ["sparkles", "circle.hexagongrid", "cpu"] {
            guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Codex") else {
                continue
            }
            let configuration = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
            let configuredImage = image.withSymbolConfiguration(configuration) ?? image
            configuredImage.isTemplate = true
            return configuredImage
        }
        return nil
    }

    private func installedOpenAIAppIcon() -> NSImage? {
        let bundleIdentifiers = [
            "com.openai.codex",
            "com.openai.chat"
        ]
        for bundleIdentifier in bundleIdentifiers {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
               let image = menuIcon(fromAppAt: appURL) {
                return image
            }
        }

        let appPaths = [
            "/Applications/Codex.app",
            "/Applications/ChatGPT.app"
        ]
        for appPath in appPaths where FileManager.default.fileExists(atPath: appPath) {
            if let image = menuIcon(fromAppAt: URL(fileURLWithPath: appPath)) {
                return image
            }
        }
        return nil
    }

    private func menuIcon(fromAppAt appURL: URL) -> NSImage? {
        let source = NSWorkspace.shared.icon(forFile: appURL.path)
        guard let image = source.copy() as? NSImage else {
            return nil
        }
        image.size = NSSize(width: 16, height: 16)
        image.isTemplate = false
        return image
    }

    private var primarySummary: String {
        guard let primary = latest?.result.rateLimits.primary else {
            return isRefreshing ? "Codex: refreshing..." : "Codex: no snapshot yet"
        }
        return "Codex: \(primary.usedPercent)% used, \(max(0, 100 - primary.usedPercent))% left"
    }

    private var resetSummary: String {
        guard let primary = latest?.result.rateLimits.primary else {
            return "Reset: unknown"
        }
        if let resetsAt = primary.resetsAt {
            return "Reset: \(formatEpoch(resetsAt))"
        }
        return "Reset: \(formatDuration(minutes: primary.windowDurationMins)) window"
    }

    private var weeklySummary: String {
        guard let secondary = latest?.result.rateLimits.secondary else {
            return "Weekly: unknown"
        }
        let resetText = secondary.resetsAt.map(formatEpoch) ?? "unknown reset"
        return "Weekly: \(secondary.usedPercent)% used, resets \(resetText)"
    }

    private var sparkSummary: String? {
        guard
            let buckets = latest?.result.rateLimitsByLimitId,
            let spark = buckets.values.first(where: { snapshot in
                snapshot.limitName?.localizedCaseInsensitiveContains("Spark") == true
                    || snapshot.limitId?.localizedCaseInsensitiveContains("bengalfox") == true
            }),
            let primary = spark.primary
        else {
            return nil
        }
        let name = spark.limitName ?? spark.limitId ?? "Spark"
        return "\(name): \(primary.usedPercent)% used"
    }

    private var creditsSummary: String {
        guard let credits = latest?.result.rateLimits.credits else {
            return "Credits: not reported"
        }
        if credits.unlimited {
            return "Credits: unlimited"
        }
        if let balance = credits.balance {
            return "Credits: \(balance)"
        }
        return credits.hasCredits ? "Credits: available" : "Credits: none"
    }

    private var freshnessSummary: String {
        guard let fetchedAt = latest?.fetchedAt else {
            return "Last refresh: never"
        }
        return "Last refresh: \(Self.shortDateFormatter.string(from: fetchedAt))"
    }

    private func saveCache(_ cache: CachedRateLimits) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cache)
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            latestError = "cache write failed: \(error.localizedDescription)"
        }
    }

    private func loadCache() -> CachedRateLimits? {
        do {
            let data = try Data(contentsOf: cacheURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(CachedRateLimits.self, from: data)
        } catch {
            return nil
        }
    }

    private func formatEpoch(_ epoch: Int64) -> String {
        Self.resetDateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(epoch)))
    }

    private func formatDuration(minutes: Int64?) -> String {
        guard let minutes else { return "unknown" }
        return formatDuration(TimeInterval(minutes * 60))
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }

    private static let resetDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
