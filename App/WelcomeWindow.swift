import AppKit
import SwiftUI

/// Shown once, the first time someone opens No Dim, in three steps in one window: what it does
/// and how to get it into Control Center (apps can't add their own controls there), the settings,
/// and how to get back to them. `nodim://welcome` shows it again.
@MainActor
final class WelcomeWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    var isVisible: Bool { window?.isVisible ?? false }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: WelcomeView(done: { [weak self] in self?.window?.close() }))
            hosting.sizingOptions = [.preferredContentSize]
            let window = NSWindow(contentViewController: hosting)
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.title = "Welcome to No Dim"
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        Pref.hasSeenWelcome = true
        window = nil // start again from step 1 if it's shown again
    }
}

private struct WelcomeView: View {
    let done: () -> Void
    @State private var page = 0
    @AppStorage(Pref.Key.showInMenuBar) private var showInMenuBar = false

    private let buttonTitles = ["Get Started", "Continue", "Done"]

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                switch page {
                case 0: welcome.transition(slide)
                case 1: settings.transition(slide)
                default: allSet.transition(slide)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()

            HStack(spacing: 6) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(i == page ? Color.accentColor : Color.primary.opacity(0.18))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.bottom, 16)

            Button(buttonTitles[page]) {
                if page < 2 {
                    withAnimation(.easeInOut(duration: 0.25)) { page += 1 }
                } else {
                    done()
                }
            }
            .buttonStyle(AccentCapsuleButtonStyle(large: true))
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 36)
        .padding(.top, 28)
        .padding(.bottom, 28)
        .frame(width: 440, height: 560)
    }

    private var slide: AnyTransition {
        .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity))
    }

    // Step 1: what it is and how to add it to Control Center.
    private var welcome: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            title("Welcome to No Dim")
            subtitle("Keeps your screen on for as long as you want. Switch it on and off from Control Center.")
            VStack(alignment: .leading, spacing: 16) {
                Step(icon: Image(Shared.macKind.symbol(awake: true)), title: "Add it to Control Center",
                     text: "Open Control Center, click Edit Controls, find No Dim in the list and drag it in.")
                Step(icon: Image(systemName: "arrow.left.and.right"), title: "Make it wide",
                     text: "Right-click the tile and choose Size → Medium to see Always On or Can Sleep.")
            }
            .padding(.top, 24)
        }
    }

    // Step 2: the same options as the settings panel.
    private var settings: some View {
        VStack(spacing: 0) {
            title("Settings")
            subtitle("Choose how No Dim behaves. You can change these anytime.")
            SettingsOptionsList()
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.05)))
                .padding(.top, 18)
        }
    }

    // Step 3: how to get back to the settings.
    private var allSet: some View {
        VStack(spacing: 0) {
            Image(systemName: "gearshape")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(Circle().fill(Color.accentColor))
                .padding(.top, 60)
            title("You're all set")
            subtitle(showInMenuBar
                     ? "To see these settings again, reopen No Dim, or click its icon in the menu bar."
                     : "To see these settings again, just reopen No Dim.")
        }
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 22, weight: .bold))
            .padding(.top, 10)
    }

    private func subtitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 6)
    }
}

/// An icon in a blue circle (like the settings panel's switched-on rows), a bold line and a note.
private struct Step: View {
    let icon: Image
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            icon
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.accentColor))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
