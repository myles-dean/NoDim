import Foundation
import IOKit.pwr_mgt
import Observation
import WidgetKit
import os

/// Holds (or doesn't hold) the power assertion that keeps the screen on, and tells
/// Control Center whenever that changes.
@MainActor @Observable
final class AwakeController {
    static let shared = AwakeController()

    enum Reason { case user, launch, chargerConnected, chargerDisconnected, lowBattery, quit }

    private(set) var isAwake = false

    @ObservationIgnored private var assertionID = IOPMAssertionID(0)
    @ObservationIgnored private var heldType: String?
    private let log = Logger(subsystem: Shared.appBundleID, category: "Awake")

    func set(_ on: Bool, reason: Reason) {
        guard on != isAwake else { publish(); return }
        isAwake = on
        apply()
        publish()
        log.info("\(on ? "On" : "Off", privacy: .public) (\(String(describing: reason), privacy: .public))")
        Notifier.announce(on: isAwake, reason: reason)
    }

    /// Makes the held assertion match `isAwake` and the "Allow display sleep" setting.
    /// Display sleep blocked → PreventUserIdleDisplaySleep (also keeps the Mac awake).
    /// Display sleep allowed → PreventUserIdleSystemSleep (Mac stays awake, screen may turn off).
    func apply() {
        let wanted: String? = isAwake
            ? (Pref.allowDisplaySleep ? kIOPMAssertionTypePreventUserIdleSystemSleep : kIOPMAssertionTypePreventUserIdleDisplaySleep) as String
            : nil
        guard wanted != heldType else { return }
        release()
        guard let wanted else { return }
        var id = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(wanted as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                 "No Dim is keeping your screen on" as CFString, &id)
        if result == kIOReturnSuccess {
            assertionID = id
            heldType = wanted
        } else {
            log.error("IOPMAssertionCreateWithName failed: \(result)")
            isAwake = false
        }
    }

    /// Writes the state where the extension can read it and asks Control Center to redraw.
    func publish() {
        Shared.defaults.set(isAwake, forKey: Shared.Key.isAwake)
        ControlCenter.shared.reloadControls(ofKind: Shared.toggleKind)
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }

    /// Posted on every publish (the menu bar icon follows it).
    static let didChange = Notification.Name("NoDimAwakeDidChange")

    private func release() {
        guard heldType != nil else { return }
        IOPMAssertionRelease(assertionID)
        heldType = nil
        assertionID = 0
    }
}
