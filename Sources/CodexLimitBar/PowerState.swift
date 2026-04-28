import Foundation
import IOKit.ps

enum PowerState {
    static var isOnBattery: Bool {
        guard
            let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return false
        }

        for source in sources {
            guard
                let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                let state = description[kIOPSPowerSourceStateKey as String] as? String
            else {
                continue
            }
            if state == kIOPSBatteryPowerValue {
                return true
            }
        }
        return false
    }

    static var refreshInterval: TimeInterval {
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return 1800
        }
        return isOnBattery ? 600 : 900
    }

    static var description: String {
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            return "Low Power"
        }
        return isOnBattery ? "Battery" : "Power Adapter"
    }
}
