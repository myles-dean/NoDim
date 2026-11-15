import AppIntents
import AppKit

/// The Control Center toggle's action (also usable from Shortcuts).
///
/// It's compiled into both the app and the extension, so the system may run it in either.
/// Inside the app it applies the change directly; inside the sandboxed extension, which can't
/// hold a power assertion beyond its own short life, it hands the request to the app.
struct SetAwakeIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Keep Screen On"
    static let description = IntentDescription("Keeps your screen on until you turn it off.")

    @Parameter(title: "Keep Awake")
    var value: Bool

    init() {}
    init(value: Bool) { self.value = value }

    func perform() async throws -> some IntentResult {
        await AwakeRequest.send(value)
        return .result()
    }
}

enum AwakeRequest {
    /// Set by the app at launch. Present only when this code is running inside the app.
    @MainActor static var handler: ((Bool) -> Void)?

    static func send(_ on: Bool) async {
        if let handler = await handler {
            await MainActor.run { handler(on) }
            return
        }
        let defaults = Shared.defaults
        defaults.set(on, forKey: Shared.Key.request)
        defaults.set(Date(), forKey: Shared.Key.requestDate)

        if Shared.appIsRunning {
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                                 CFNotificationName(Shared.requestNotification), nil, nil, true)
        } else if on {
            // The app reads the fresh request when it starts. (Nothing to do to turn off
            // when the app isn't running: nothing is holding the screen awake.)
            await launchApp()
        } else {
            defaults.set(false, forKey: Shared.Key.isAwake)
            return
        }

        // Wait for the app to confirm, so Control Center redraws with the real state.
        for _ in 0..<60 {
            if defaults.bool(forKey: Shared.Key.isAwake) == on { return }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    private static func launchApp() async {
        // The extension lives at No Dim.app/Contents/PlugIns/NoDimControls.appex.
        let containing = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard let url = containing.pathExtension == "app" ? containing
                : NSWorkspace.shared.urlForApplication(withBundleIdentifier: Shared.appBundleID) else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        config.addsToRecentItems = false
        config.arguments = ["--from-control"]
        _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: config)
    }
}
