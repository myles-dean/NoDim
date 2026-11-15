import AppKit
import ServiceManagement
import SwiftUI

/// No Dim's settings, shown the way Control Center shows a module: a Liquid Glass panel at
/// the top right of the screen that closes when you click anywhere else or press Escape. Opening
/// the app (Spotlight, Launchpad, Finder) shows it.
@MainActor
final class SettingsPanelController: NSObject, NSWindowDelegate {
    private let panel: SettingsPanel
    private let hosting = NSHostingView(rootView: SettingsPanelView(fromMenuBar: false, close: {}))
    private static let cornerRadius: CGFloat = 24

    override init() {
        // Non-activating, like menu bar extras: it can show (and take Escape) while another app is
        // active, which is always the case when you click No Dim's menu bar icon.
        panel = SettingsPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        super.init()
        panel.hidesOnDeactivate = false // panels hide whenever their app isn't active by default
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.delegate = self

        let glass = NSGlassEffectView()
        glass.style = .regular
        glass.cornerRadius = Self.cornerRadius
        glass.contentView = hosting
        glass.autoresizingMask = [.width, .height]

        // The glass rounds its own fill, but its backdrop and the window around it stay
        // rectangular, so clip everything to the same rounded shape (the shadow follows it).
        let clip = NSView()
        clip.wantsLayer = true
        clip.layer?.backgroundColor = .clear
        clip.layer?.cornerRadius = Self.cornerRadius
        clip.layer?.cornerCurve = .continuous
        clip.layer?.masksToBounds = true
        clip.addSubview(glass)
        panel.contentView = clip
    }

    var isVisible: Bool { panel.isVisible }
    private var hiddenAt = Date.distantPast
    private var outsideClicks: Any?

    /// From the menu bar icon: opens under it, or closes if it's open (including when the click on
    /// the icon is what just closed it).
    func toggle(below anchor: NSView) {
        if panel.isVisible || Date().timeIntervalSince(hiddenAt) < 0.3 { hide() } else { show(below: anchor) }
    }

    /// At the top right of the screen the pointer is on (where Control Center opens), or centred
    /// under `anchor` (the menu bar icon).
    func show(below anchor: NSView? = nil) {
        // Rebuilt each time (re-reads the login item status). From the menu bar it drops down like
        // a menu, so no Close button or reopen note.
        hosting.rootView = SettingsPanelView(fromMenuBar: anchor != nil, close: { [weak self] in self?.hide() })
        let size = hosting.fittingSize
        var frame = NSRect(origin: .zero, size: size)
        if let anchor, let window = anchor.window, let visible = window.screen?.visibleFrame {
            let icon = window.convertToScreen(anchor.convert(anchor.bounds, to: nil))
            frame.origin.x = min(max(icon.midX - size.width / 2, visible.minX + 8), visible.maxX - size.width - 8)
            frame.origin.y = icon.minY - size.height - 6
        } else {
            let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
            guard let visible = screen?.visibleFrame else { return }
            frame.origin = NSPoint(x: visible.maxX - size.width - 8, y: visible.maxY - size.height - 6)
        }
        panel.setFrame(frame, display: true)
        panel.contentView?.subviews.first?.frame = panel.contentView?.bounds ?? .zero
        if !panel.isVisible { panel.alphaValue = 0 }
        if anchor == nil { NSApp.activate() } // opened as an app: come to the front
        panel.makeKeyAndOrderFront(nil)
        // Close on a click anywhere outside it. (Clicks in other apps don't reach this one as key
        // changes when it never activated.)
        if outsideClicks == nil {
            outsideClicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
                MainActor.assumeIsolated { self?.hide() }
            }
        }
        panel.invalidateShadow() // recompute the shadow from the rounded shape
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.15; panel.animator().alphaValue = 1 }) { [panel] in
            MainActor.assumeIsolated { panel.invalidateShadow() }
        }
    }

    func hide() {
        if let outsideClicks { NSEvent.removeMonitor(outsideClicks) }
        outsideClicks = nil
        guard panel.isVisible else { return }
        hiddenAt = Date()
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.12; panel.animator().alphaValue = 0 }) { [panel] in
            MainActor.assumeIsolated { panel.orderOut(nil) }
        }
    }

    // Clicking anywhere else (another app, the desktop, the menu bar) takes key status away.
    func windowDidResignKey(_ notification: Notification) { hide() }
}

final class SettingsPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { (delegate as? SettingsPanelController)?.hide() }
}

// MARK: - Contents (laid out like Control Center's Wi-Fi and Focus menus)

struct SettingsPanelView: View {
    let fromMenuBar: Bool
    let close: () -> Void
    private var awake = AwakeController.shared

    init(fromMenuBar: Bool, close: @escaping () -> Void) {
        self.fromMenuBar = fromMenuBar
        self.close = close
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("No Dim")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Toggle("No Dim", isOn: Binding(get: { awake.isAwake }, set: { awake.set($0, reason: .user) }))
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            PanelDivider()

            SettingsOptionsList()

            PanelDivider()

            HStack(spacing: 4) {
                TextRow(title: "Quit") { NSApp.terminate(nil) }
                if !fromMenuBar {
                    Button("Close", action: close)
                        .buttonStyle(AccentCapsuleButtonStyle())
                        .keyboardShortcut(.defaultAction)
                        .padding(.trailing, 16)
                }
            }
            .padding(.top, 6)
            .padding(.bottom, fromMenuBar ? 8 : 0)

            if !fromMenuBar {
                Text("Open app again anytime to see these settings.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 12)
            }
        }
        .frame(width: 310)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The option rows, shared by the settings panel and the welcome window's settings step.
struct SettingsOptionsList: View {
    private var awake = AwakeController.shared

    @AppStorage(Pref.Key.activateAtLaunch) private var activateAtLaunch = false
    @AppStorage(Pref.Key.allowDisplaySleep) private var allowDisplaySleep = false
    @AppStorage(Pref.Key.allowNotifications) private var allowNotifications = false
    @AppStorage(Pref.Key.activateOnPowerConnect) private var activateOnPowerConnect = false
    @AppStorage(Pref.Key.deactivateOnPowerDisconnect) private var deactivateOnPowerDisconnect = false
    @AppStorage(Pref.Key.deactivateOnLowBattery) private var deactivateOnLowBattery = false
    @AppStorage(Pref.Key.showInMenuBar) private var showInMenuBar = false

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    private let hasBattery = MacKind.hasInternalBattery

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 2) {
                OptionRow(symbol: "power", title: "Launch at login", isOn: launchAtLogin) { setLaunchAtLogin(!launchAtLogin) }
                OptionRow(symbol: "togglepower", title: "Turn on at launch", isOn: activateAtLaunch) { activateAtLaunch.toggle() }
                OptionRow(symbol: "sleep", title: "Allow display sleep", isOn: allowDisplaySleep) {
                    allowDisplaySleep.toggle()
                    awake.apply()
                }
                OptionRow(symbol: "bell", title: "Allow notifications", isOn: allowNotifications) { setAllowNotifications(!allowNotifications) }
                OptionRow(symbol: "menubar.rectangle", title: "Show in menu bar", isOn: showInMenuBar) { showInMenuBar.toggle() }
            }
            .padding(.vertical, 6)

            if hasBattery {
                PanelDivider()
                VStack(spacing: 2) {
                    OptionRow(symbol: "bolt", title: "Turn on when charger connects", isOn: activateOnPowerConnect) { activateOnPowerConnect.toggle() }
                    OptionRow(symbol: "bolt.slash", title: "Turn off when charger disconnects", isOn: deactivateOnPowerDisconnect) { deactivateOnPowerDisconnect.toggle() }
                    OptionRow(symbol: "battery.25percent", title: "Turn off below \(Pref.lowBatteryPercent)% battery", isOn: deactivateOnLowBattery) { deactivateOnLowBattery.toggle() }
                }
                .padding(.vertical, 6)
            }
        }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("No Dim: couldn't change the login item: \(error.localizedDescription)")
        }
        if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func setAllowNotifications(_ on: Bool) {
        guard on else { allowNotifications = false; return }
        Task {
            allowNotifications = await Notifier.requestPermission()
            if !allowNotifications, let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                NSWorkspace.shared.open(url) // turned off in System Settings: send them there
            }
        }
    }
}

private struct PanelDivider: View {
    var body: some View {
        Divider().padding(.horizontal, 16)
    }
}

/// An icon in a circle (blue when the option is on) and its name; clicking anywhere on it toggles.
private struct OptionRow: View {
    let symbol: String
    let title: String
    let isOn: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isOn ? Color.white : Color.primary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(isOn ? Color.accentColor : Color.primary.opacity(0.1)))
                Text(title)
                    .font(.system(size: 13))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
            .background(RoundedRectangle(cornerRadius: 9).fill(hovering ? Color.primary.opacity(0.08) : .clear))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .padding(.horizontal, 8)
        .animation(.easeOut(duration: 0.12), value: isOn)
    }
}

/// A capsule in the same accent blue as the switched-on option circles and the main switch.
struct AccentCapsuleButtonStyle: ButtonStyle {
    var large = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: large ? 14 : 13, weight: large ? .semibold : .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, large ? 28 : 14)
            .padding(.vertical, large ? 8 : 5)
            .background(Capsule().fill(Color.accentColor))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(Capsule())
    }
}

/// A plain menu-style item, like "Focus Settings…".
private struct TextRow: View {
    let title: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .background(RoundedRectangle(cornerRadius: 9).fill(hovering ? Color.primary.opacity(0.08) : .clear))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .padding(.horizontal, 8)
    }
}
