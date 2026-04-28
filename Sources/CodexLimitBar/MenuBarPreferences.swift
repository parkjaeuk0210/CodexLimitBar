import Foundation

enum MenuBarLimitMode: String {
    case fiveHour
    case weekly

    static let defaultsKey = "menuBarLimitMode"

    static var saved: MenuBarLimitMode {
        let stored = UserDefaults.standard.string(forKey: defaultsKey)
        return stored.flatMap(MenuBarLimitMode.init(rawValue:)) ?? .fiveHour
    }

    var title: String {
        switch self {
        case .fiveHour:
            return "5-Hour Limit"
        case .weekly:
            return "Weekly Limit"
        }
    }
}
