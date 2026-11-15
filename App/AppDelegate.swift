import AppKit
import UserNotifications

/// No Dim runs in the background with no Dock icon (and a menu bar icon only if you turn it on).
/// You switch it from Control Center; opening the app shows a one-time welcome window, then its
/// settings panel at the top right, like a Control Center module.
@main @MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    private let power = PowerMonitor()
    private lazy var settings = SettingsPanelController()
    private lazy var welcome = WelcomeWindowController()
    private lazy var menuBar = MenuBarItem(panel: settings)
    private var handledControlSinceLaunch = false
    private var isQuitting = false
    private var termSignal: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()
        UNUserNotificationCenter.current().delegate = self

        Shared.defaults.set(MacKind.detect().rawValue, forKey: Shared.Key.macKind)
        AppIconUpdater.applyIconForThisMac()

        let awake = AwakeController.shared
        AwakeRequest.handler = { [weak self] on in
            self?.handledControlSinceLaunch = true
            awake.set(on, reason: .user)
        }
        observeControlRequests()

        power.onChange = { old, new in Self.powerChanged(from: old, to: new) }
        power.start()
        menuBar.sync() // adds the menu bar icon if "Show in menu bar" is on
        handleTermSignal()

        // Launched by the Control Center toggle → do what it asked; otherwise maybe turn on.
        let fromControl = CommandLine.arguments.contains("--from-control") || CommandLine.arguments.contains("--background")
        if let request = recentControlRequest() {
            handledControlSinceLaunch = true
            awake.set(request, reason: .user)
        } else if Pref.activateAtLaunch {
            awake.set(true, reason: .launch)
        } else {
            awake.publish()
        }

        // When someone opens the app themselves (not at login, not for a control): the welcome
        // window the first time, the settings panel after that. nodim:// links handle themselves.
        let event = NSAppleEventManager.shared().currentAppleEvent
        let isOpenApp = event?.eventClass == kCoreEventClass && event?.eventID == kAEOpenApplication
        let isLoginItem = event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if !fromControl && !isLoginItem && (isOpenApp || !Pref.hasSeenWelcome) {
            // A control's action can arrive just after launch; don't pop anything up for it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [self] in
                guard !handledControlSinceLaunch else { return }
                if Pref.hasSeenWelcome { settings.show() } else { welcome.show() }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if welcome.isVisible || !Pref.hasSeenWelcome { welcome.show() } else { settings.show() }
        return false
    }

    /// nodim://settings, nodim://on, nodim://off, nodim://toggle, nodim://welcome, and
    /// nodim://look/laptop|imac|macmini|auto to preview another Mac's glyphs.
    func application(_ application: NSApplication, open urls: [URL]) {
        let awake = AwakeController.shared
        for url in urls where url.scheme == "nodim" {
            switch url.host() {
            case "on": awake.set(true, reason: .user)
            case "off": awake.set(false, reason: .user)
            case "toggle": awake.set(!awake.isAwake, reason: .user)
            case "welcome": welcome.show()
            case "look":
                let kind = MacKind(rawValue: url.lastPathComponent)
                Shared.defaults.set(kind?.rawValue, forKey: Shared.Key.macKindOverride)
                awake.publish()
            default: settings.show()
            }
        }
    }

    // MARK: - Quitting
    //
    // Quitting turns No Dim off. The off state has to reach Control Center before the process
    // exits, or the tile keeps showing Always On: so switch off, then exit half a second later.

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isQuitting else { return .terminateNow }
        isQuitting = true
        turnOffForQuit()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { NSApp.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        turnOffForQuit() // already off unless termination skipped applicationShouldTerminate
    }

    private func turnOffForQuit() {
        AwakeController.shared.set(false, reason: .quit) // releases the assertion, tells Control Center
        Shared.defaults.synchronize()
    }

    /// `kill`/`pkill`/installers send SIGTERM, which AppKit doesn't turn into a normal quit:
    /// handle it the same way instead of dying with the tile still showing Always On.
    private func handleTermSignal() {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { [weak self] in
            guard let self, !self.isQuitting else { return }
            self.isQuitting = true
            self.turnOffForQuit()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { exit(0) }
        }
        source.resume()
        termSignal = source
    }

    // Banners even while the settings window is in front.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    // MARK: - Control Center requests

    /// The extension writes {request, requestDate} to the shared defaults and posts a Darwin notification.
    private func observeControlRequests() {
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), Unmanaged.passUnretained(self).toOpaque(),
                                        { _, observer, _, _, _ in
            let delegate = Unmanaged<AppDelegate>.fromOpaque(observer!).takeUnretainedValue()
            Task { @MainActor in
                guard let request = delegate.recentControlRequest() else { return }
                delegate.handledControlSinceLaunch = true
                AwakeController.shared.set(request, reason: .user)
            }
        }, Shared.requestNotification, nil, .deliverImmediately)
    }

    /// A request the extension made in the last few seconds (consumed once read).
    private func recentControlRequest() -> Bool? {
        let defaults = Shared.defaults
        guard let date = defaults.object(forKey: Shared.Key.requestDate) as? Date,
              abs(date.timeIntervalSinceNow) < 10 else { return nil }
        defaults.removeObject(forKey: Shared.Key.requestDate)
        return defaults.bool(forKey: Shared.Key.request)
    }

    // MARK: - Charger and battery

    private static func powerChanged(from old: PowerMonitor.Snapshot, to new: PowerMonitor.Snapshot) {
        let awake = AwakeController.shared
        if !old.onCharger && new.onCharger && Pref.activateOnPowerConnect && !awake.isAwake {
            awake.set(true, reason: .chargerConnected)
        }
        if old.onCharger && !new.onCharger && Pref.deactivateOnPowerDisconnect && awake.isAwake {
            awake.set(false, reason: .chargerDisconnected)
        }
        if !new.onCharger, let before = old.batteryPercent, let now = new.batteryPercent,
           before >= Pref.lowBatteryPercent, now < Pref.lowBatteryPercent,
           Pref.deactivateOnLowBattery, awake.isAwake {
            awake.set(false, reason: .lowBattery)
        }
    }

    // MARK: - Menu (hidden, but its shortcuts work while the settings window is in front)

    private func makeMainMenu() -> NSMenu {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appMenu.addItem(withTitle: "Quit No Dim", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        return main
    }
}
