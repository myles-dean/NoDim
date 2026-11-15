import Foundation

/// The settings window's switches (stored in the app's own defaults; SwiftUI binds to the same keys
/// with @AppStorage).
enum Pref {
    enum Key {
        static let activateAtLaunch = "activateAtLaunch"
        static let allowDisplaySleep = "allowDisplaySleep"
        static let allowNotifications = "allowNotifications"
        static let activateOnPowerConnect = "activateOnPowerConnect"
        static let deactivateOnPowerDisconnect = "deactivateOnPowerDisconnect"
        static let deactivateOnLowBattery = "deactivateOnLowBattery"
        static let showInMenuBar = "showInMenuBar"
        static let hasSeenWelcome = "hasSeenWelcome"
    }

    private static var d: UserDefaults { .standard }
    static var activateAtLaunch: Bool { d.bool(forKey: Key.activateAtLaunch) }
    static var allowDisplaySleep: Bool { d.bool(forKey: Key.allowDisplaySleep) }
    static var allowNotifications: Bool { d.bool(forKey: Key.allowNotifications) }
    static var activateOnPowerConnect: Bool { d.bool(forKey: Key.activateOnPowerConnect) }
    static var deactivateOnPowerDisconnect: Bool { d.bool(forKey: Key.deactivateOnPowerDisconnect) }
    static var deactivateOnLowBattery: Bool { d.bool(forKey: Key.deactivateOnLowBattery) }
    static var showInMenuBar: Bool { d.bool(forKey: Key.showInMenuBar) }
    static var hasSeenWelcome: Bool {
        get { d.bool(forKey: Key.hasSeenWelcome) }
        set { d.set(newValue, forKey: Key.hasSeenWelcome) }
    }

    /// "Turn off when battery is below 20%" fires when the level drops under this.
    static let lowBatteryPercent = 20
}
