import Foundation
import IOKit.ps

/// Watches the charger and battery level and reports each change as (before, after).
@MainActor
final class PowerMonitor {
    struct Snapshot: Equatable {
        var onCharger: Bool
        /// nil on Macs without a built-in battery.
        var batteryPercent: Int?
    }

    var onChange: ((Snapshot, Snapshot) -> Void)?
    private(set) var current = PowerMonitor.read()
    private var source: CFRunLoopSource?

    static var hasBattery: Bool { read().batteryPercent != nil }

    func start() {
        current = Self.read()
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            let monitor = Unmanaged<PowerMonitor>.fromOpaque(context!).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.update() }
        }, context)?.takeRetainedValue() else { return }
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    private func update() {
        let new = Self.read()
        guard new != current else { return }
        let old = current
        current = new
        onChange?(old, new)
    }

    static func read() -> Snapshot {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            return Snapshot(onCharger: true, batteryPercent: nil)
        }
        let providing = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
        var percent: Int?
        let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] ?? []
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let capacity = description[kIOPSCurrentCapacityKey] as? Int,
                  let max = description[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            percent = capacity * 100 / max
        }
        return Snapshot(onCharger: providing == kIOPMACPowerKey, batteryPercent: percent)
    }
}
