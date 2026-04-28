import Foundation

struct MenuBarTitleFormatter {
    let displayMode: MenuBarLimitMode

    func title(snapshot: RateLimitSnapshot?, isInitialRefresh: Bool, latestError: String?) -> String {
        if isInitialRefresh {
            return "..."
        }
        guard let snapshot else {
            return latestError == nil ? "..." : "?"
        }
        if snapshot.rateLimitReachedType != nil {
            return "LIMIT"
        }

        let window: RateLimitWindow?
        switch displayMode {
        case .fiveHour:
            window = snapshot.primary
        case .weekly:
            window = snapshot.secondary
        }

        guard let used = window?.usedPercent else { return "?" }
        let remaining = max(0, 100 - used)
        return "\(remaining)%"
    }
}
