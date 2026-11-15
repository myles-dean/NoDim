import AppKit
import os

/// No Dim ships with a neutral icon (a screen with ∞), since one download serves every Mac. On
/// launch it gives itself the icon for the Mac it's on — a laptop, an iMac or a Mac mini — as a
/// Finder custom icon, the same thing Finder's Get Info → paste icon does. Updates replace the
/// app (and the custom icon with it), so it's checked every launch and re-applied when missing.
///
/// A custom icon is an extra file in the app folder, so `codesign --verify` reports the installed
/// app as modified afterwards; macOS keeps launching it. The sandbox only allows this for
/// /Applications/No Dim.app (and ~/Applications/No Dim.app), so copies elsewhere keep the neutral icon.
@MainActor
enum AppIconUpdater {
    private static let log = Logger(subsystem: Shared.appBundleID, category: "AppIcon")
    private static let appliedKey = "appliedAppIcon"
    /// Bump when the icon images change, so installed copies get the new one.
    private static let revision = 3

    static func applyIconForThisMac() {
        let kind = MacKind.detect()
        // 1024 px PNGs drawn by macOS at build time in its current icon shape (an .icns from
        // actool has older, squarer corners that stood out in the Dock).
        guard let url = Bundle.main.url(forResource: "AppIcon-\(kind.rawValue)", withExtension: "png"),
              let icon = NSImage(contentsOf: url) else { return }
        icon.size = NSSize(width: 512, height: 512)
        NSApp.applicationIconImage = icon // the welcome window and alerts show it right away

        let bundle = Bundle.main.bundlePath
        let stamp = "\(revision)|\(kind.rawValue)|\(bundle)"
        let hasCustomIcon = FileManager.default.fileExists(atPath: bundle + "/Icon\r")
        guard !(hasCustomIcon && UserDefaults.standard.string(forKey: appliedKey) == stamp) else { return }

        if NSWorkspace.shared.setIcon(icon, forFile: bundle, options: []) {
            UserDefaults.standard.set(stamp, forKey: appliedKey)
            log.info("Applied the \(kind.rawValue, privacy: .public) icon")
        } else {
            log.info("Couldn't set the app icon at \(bundle, privacy: .public) (outside /Applications or read-only)")
        }
    }
}
