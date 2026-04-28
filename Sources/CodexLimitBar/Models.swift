import Foundation

struct RateLimitWindow: Codable {
    let resetsAt: Int64?
    let usedPercent: Int
    let windowDurationMins: Int64?
}

struct CreditsSnapshot: Codable {
    let balance: String?
    let hasCredits: Bool
    let unlimited: Bool
}

struct RateLimitSnapshot: Codable {
    let credits: CreditsSnapshot?
    let limitId: String?
    let limitName: String?
    let planType: String?
    let primary: RateLimitWindow?
    let rateLimitReachedType: String?
    let secondary: RateLimitWindow?
}

struct RateLimitsReadResult: Codable {
    let rateLimits: RateLimitSnapshot
    let rateLimitsByLimitId: [String: RateLimitSnapshot]?
}

struct CachedRateLimits: Codable {
    let fetchedAt: Date
    let result: RateLimitsReadResult
}

enum LimitFetchError: LocalizedError {
    case codexNotFound
    case noFreePort
    case appServerNotReady
    case rpcError(String)
    case malformedResponse

    var errorDescription: String? {
        switch self {
        case .codexNotFound:
            return "codex executable was not found"
        case .noFreePort:
            return "could not find a free local port"
        case .appServerNotReady:
            return "codex app-server did not become ready"
        case .rpcError(let message):
            return message
        case .malformedResponse:
            return "codex app-server returned an unexpected response"
        }
    }
}
