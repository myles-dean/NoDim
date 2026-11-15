// Build-time helper: draws what macOS shows for an app bundle's icon (rendered by the system from
// its Icon Composer asset, in the current icon shape) into a 1024 px PNG.
//
//   render-app-icon <bundle.app> <out.png>
//
// The .icns that actool also writes uses an older, squarer shape, which looked off in the Dock
// next to other apps once No Dim used it as its custom icon.

import AppKit

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write("usage: render-app-icon <bundle.app> <out.png>\n".data(using: .utf8)!)
    exit(2)
}
let icon = NSWorkspace.shared.icon(forFile: args[1])
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: 512, height: 512)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSAppearance(named: .aqua)!.performAsCurrentDrawingAppearance {
    icon.draw(in: NSRect(x: 0, y: 0, width: 512, height: 512))
}
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
