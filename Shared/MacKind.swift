import CoreGraphics
import Foundation
import IOKit.ps

/// Which glyph fits this Mac: a laptop, an iMac, or the Mac mini box (also used for Mac Studio and
/// Mac Pro, which are boxes too). Each has an "infinity" (on) and a "sleep" (off) symbol drawn by
/// Tools/make-symbol.swift.
enum MacKind: String, CaseIterable {
    case laptop, imac, macmini

    func symbol(awake: Bool) -> String { "\(rawValue).\(awake ? "infinity" : "sleep")" }

    /// Older models say what they are (MacBookPro18,1, iMac21,1, Macmini9,1); Apple silicon ones
    /// since 2022 are just "MacNN,N", so then: a built-in battery means a laptop, a built-in
    /// screen without one means an iMac, anything else is a desktop box.
    static func detect() -> MacKind {
        let model = hardwareModel
        if model.hasPrefix("MacBook") { return .laptop }
        if model.hasPrefix("iMac") { return .imac }
        if model.hasPrefix("Macmini") || model.hasPrefix("MacPro") { return .macmini }
        if hasInternalBattery { return .laptop }
        if hasBuiltInDisplay { return .imac }
        return .macmini
    }

    static var hardwareModel: String {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else { return "" }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &buffer, &size, nil, 0) == 0 else { return "" }
        return String(cString: buffer)
    }

    static var hasInternalBattery: Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return false }
        return sources.contains { source in
            let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any]
            return description?[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
        }
    }

    /// Online (not just active) displays, so a sleeping iMac screen still counts.
    static var hasBuiltInDisplay: Bool {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return false }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &displays, &count) == .success else { return false }
        return displays.prefix(Int(count)).contains { CGDisplayIsBuiltin($0) != 0 }
    }
}

extension Shared {
    /// The glyph set to draw. The app stores what it detected at launch (the extension may not be
    /// able to see the displays); `nodim://look/<kind>` can override it to preview the others.
    static var macKind: MacKind {
        if let raw = defaults.string(forKey: Key.macKindOverride), let kind = MacKind(rawValue: raw) { return kind }
        if let raw = defaults.string(forKey: Key.macKind), let kind = MacKind(rawValue: raw) { return kind }
        return .detect()
    }
}
