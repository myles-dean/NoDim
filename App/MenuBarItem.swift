import AppKit

/// The optional menu bar icon ("Show in menu bar", off by default): this Mac's glyph, with ∞ while
/// No Dim is on and the sleep sign while it's off. Click opens the settings panel under it;
/// right-click (or Control-click) switches No Dim on or off.
@MainActor
final class MenuBarItem: NSObject {
    private let panel: SettingsPanelController
    private var item: NSStatusItem?
    private var observers: [NSObjectProtocol] = []

    init(panel: SettingsPanelController) {
        self.panel = panel
        super.init()
        // The setting lives in the app's defaults (the panel writes it through @AppStorage).
        observers.append(NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sync() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AwakeController.didChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateImage() }
        })
    }

    /// Adds or removes the icon to match the setting.
    func sync() {
        if Pref.showInMenuBar {
            if item == nil {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                item.button?.target = self
                item.button?.action = #selector(clicked(_:))
                item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
                self.item = item
            }
            updateImage()
        } else if let item {
            NSStatusBar.system.removeStatusItem(item)
            self.item = nil
        }
    }

    private func updateImage() {
        guard let button = item?.button else { return }
        let awake = AwakeController.shared.isAwake
        let image = NSImage(symbolName: Shared.macKind.symbol(awake: awake), bundle: .main, variableValue: 1)?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .regular))
        image?.isTemplate = true
        button.image = image
        button.toolTip = awake ? "No Dim: Always On" : "No Dim: Can Sleep"
        button.setAccessibilityLabel(button.toolTip)
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            let awake = AwakeController.shared
            awake.set(!awake.isAwake, reason: .user)
        } else {
            panel.toggle(below: sender)
        }
    }
}
