import AppIntents
import SwiftUI
import WidgetKit

/// The control No Dim adds to Control Center's gallery (Control Center → Edit Controls).
/// Its settings open from the app itself (a panel at the top right), since an app's tile can't
/// expand or add to its right-click menu.
@main
struct NoDimControls: WidgetBundle {
    var body: some Widget {
        AwakeControl()
    }
}

/// On/off switch, showing just its state: "Always On" with ∞ on this Mac's screen (white tile,
/// blue glyph) or "Can Sleep" with the display-sleep sign (see-through tile, white glyph). The Mac
/// is a laptop, an iMac or a Mac mini box, whichever this Mac is.
struct AwakeControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Shared.toggleKind, provider: Provider()) { isOn in
            ControlWidgetToggle(isOn: isOn, action: SetAwakeIntent()) {
                Text(isOn ? "Always On" : "Can Sleep")
            } valueLabel: { isOn in
                Label {
                    Text("")
                } icon: {
                    Image(Shared.macKind.symbol(awake: isOn))
                }
            }
            .tint(.blue)
        }
        .displayName("No Dim")
        .description("Keeps your screen on until you turn it off.")
    }

    struct Provider: ControlValueProvider {
        var previewValue: Bool { false }
        func currentValue() async throws -> Bool { Shared.isAwake }
    }
}
