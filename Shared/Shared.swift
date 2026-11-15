import AppKit

/// What the app and its Control Center extension share: identifiers, the app-group defaults
/// that hold the current state, and the Darwin notification the extension uses to wake the app.
enum Shared {
    static let appBundleID = "com.mylesdean.NoDim"
    static let toggleKind = "com.mylesdean.NoDim.toggle"
    /// Posted by the extension after it writes a request; the app applies it.
    static let requestNotification = "com.mylesdean.NoDim.request" as CFString

    /// `<TeamID>.com.mylesdean.NoDim`, from Info.plist so the team isn't hard-coded.
    static let appGroup = Bundle.main.object(forInfoDictionaryKey: "NoDimAppGroup") as? String
        ?? "3N7MVP4K42.com.mylesdean.NoDim"
    nonisolated(unsafe) static let defaults = UserDefaults(suiteName: appGroup)!

    enum Key {
        /// Bool, written by the app: whether it's holding the screen awake right now.
        static let isAwake = "isAwake"
        /// Bool + Date, written by the extension: what the user just asked for in Control Center.
        static let request = "request"
        static let requestDate = "requestDate"
        /// String (MacKind), written by the app at launch: which Mac this is.
        static let macKind = "macKind"
        /// String (MacKind), set by nodim://look/<kind> to preview another Mac's glyphs.
        static let macKindOverride = "macKindOverride"
    }

    static var appIsRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: appBundleID).isEmpty
    }

    /// What Control Center should show: on only while the app is actually running and holding it.
    static var isAwake: Bool {
        defaults.bool(forKey: Key.isAwake) && (Bundle.main.bundleIdentifier == appBundleID || appIsRunning)
    }
}
