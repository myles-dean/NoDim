import Foundation
import UserNotifications

/// "Allow notifications": a short notice when No Dim turns itself on or off
/// (charger or battery). Turning it on or off yourself never notifies.
enum Notifier {
    static func announce(on: Bool, reason: AwakeController.Reason) {
        guard Pref.allowNotifications else { return }
        let body: String
        switch reason {
        case .chargerConnected: body = "Your charger was connected."
        case .chargerDisconnected: body = "Your charger was disconnected."
        case .lowBattery: body = "Your battery dropped below \(Pref.lowBatteryPercent)%."
        case .user, .launch, .quit: return
        }
        let content = UNMutableNotificationContent()
        content.title = on ? "No Dim is on" : "No Dim is off"
        content.body = body
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    /// Asks for permission; false if the person (or System Settings) says no.
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        if (try? await center.requestAuthorization(options: [.alert, .sound])) == true { return true }
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }
}
