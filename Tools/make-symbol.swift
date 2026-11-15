// Draws Screen Awake's glyphs — a Mac with ∞ on its screen while it's keeping the screen on, or
// Apple's display-sleep sign while it can sleep — and writes:
//   • the custom SF Symbols both targets use (Shared/Symbols.xcassets), one pair per kind of Mac:
//       laptop.infinity / laptop.sleep      MacBooks
//       imac.infinity / imac.sleep          iMac (screen and stand, no chin, like Apple's `display`)
//       macmini.infinity / macmini.sleep    Mac mini and other desktops, seen from the top: a
//                                           rounded square like a Dock icon, sign in the middle
//   • the app icon as downloaded, a screen with ∞ (App/AppIcon.icon), and one per kind of Mac
//     (App/Icons/AppIcon-<mac>.icon) that the app switches to after install
//   • a preview PNG (argument 1, optional) next to Apple's own symbols for comparison
//
//   swift Tools/make-symbol.swift [preview.png]
//
// Shapes follow Apple's `laptopcomputer`, `display` and `app` (measured from renders at 100 pt) at all nine weights and three scales, so they sit next to the built-in Control
// Center symbols at whatever weight and size Control Center asks for.
//
// The templates are static (all 27 variants drawn) with no layer annotations. With annotations
// but no layer styles, a compiled symbol draws nothing in hierarchical or palette mode — which is
// how Control Center renders control glyphs — so the tile came out blank.

import AppKit

// MARK: - Apple's laptopcomputer, measured per weight (100 pt, Medium scale, y grows downward)

struct Metrics {
    var name: String
    var advance: CGFloat       // margin to margin
    var baseline: CGFloat      // y of the baseline in these coordinates
    var lidTop: (outer: CGFloat, inner: CGFloat)
    var lidSides: (outerLeft: CGFloat, innerLeft: CGFloat, innerRight: CGFloat, outerRight: CGFloat)
    var base: (top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat)
    /// Line weight of Apple's symbols at this weight (7.9 at Regular).
    var stroke: CGFloat { lidSides.innerLeft - lidSides.outerLeft }
}

let weights: [Metrics] = [
    .init(name: "Ultralight", advance: 154, baseline: 80, lidTop: (9.5, 11.7), lidSides: (26.2, 28.6, 125.2, 127.6), base: (74.4, 80.4, 12.5, 141.2)),
    .init(name: "Thin", advance: 156.5, baseline: 81, lidTop: (8.8, 12.4), lidSides: (26.7, 30.4, 126.1, 129.7), base: (75.1, 82.3, 12.5, 143.9)),
    .init(name: "Light", advance: 162, baseline: 82.5, lidTop: (9.4, 15.3), lidSides: (27.8, 33.9, 127.9, 133.9), base: (76.1, 85.4, 12.5, 149.2)),
    .init(name: "Regular", advance: 166, baseline: 82.5, lidTop: (7.8, 15.6), lidSides: (28.7, 36.6, 129.3, 137.1), base: (76.1, 87.2, 12.5, 153.3)),
    .init(name: "Medium", advance: 169, baseline: 85, lidTop: (9.6, 19.0), lidSides: (29.0, 38.6, 130.2, 139.7), base: (78.1, 90.4, 12.5, 156.2)),
    .init(name: "Semibold", advance: 171, baseline: 86, lidTop: (9.0, 19.9), lidSides: (29.3, 40.1, 130.8, 141.7), base: (78.9, 92.3, 12.5, 158.4)),
    .init(name: "Bold", advance: 174, baseline: 87, lidTop: (8.8, 21.4), lidSides: (29.6, 42.2, 131.8, 144.3), base: (79.6, 94.3, 12.5, 161.4)),
    .init(name: "Heavy", advance: 178.5, baseline: 88.5, lidTop: (9.5, 24.4), lidSides: (30.1, 45.2, 133.1, 148.2), base: (80.9, 97.4, 12.5, 165.7)),
    .init(name: "Black", advance: 182.5, baseline: 90, lidTop: (9.6, 26.8), lidSides: (30.5, 47.8, 134.3, 151.6), base: (82.2, 100.4, 12.5, 169.5)),
]

/// Small and Large relative to Medium (laptopcomputer is 133 / 166 / 211 pt wide), scaled about
/// the middle of the cap height (symbols are vertically centred on it).
let scales: [(name: String, factor: CGFloat)] = [("S", 133.0 / 166), ("M", 1), ("L", 211.0 / 166)]
let capHeight: CGFloat = 70.5
let sideBearing: CGFloat = 12.5

enum Device: String, CaseIterable { case laptop, imac, macmini }
enum Screen: String, CaseIterable { case infinity, sleep }

// MARK: - Shapes (y grows downward)

func roundedRect(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat, _ r: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0), cornerWidth: r, cornerHeight: r, transform: nil)
}

/// A Mac outline plus the area its sign goes in.
struct Body { var path: CGPath; var signArea: CGRect }

func laptop(_ m: Metrics) -> Body {
    // Lid frame, rounder outside than inside; its bottom edge disappears into the base.
    let s = m.stroke
    let outer = roundedRect(m.lidSides.outerLeft, m.lidTop.outer, m.lidSides.outerRight, m.base.bottom - 1, 5.5 + s / 2)
    let inner = roundedRect(m.lidSides.innerLeft, m.lidTop.inner, m.lidSides.innerRight, m.base.bottom - 2, max(2, 6 - s / 4))
    let base = roundedRect(m.base.left, m.base.top, m.base.right, m.base.bottom, (m.base.bottom - m.base.top) / 2)
    let screen = CGRect(x: m.lidSides.innerLeft, y: m.lidTop.inner, width: m.lidSides.innerRight - m.lidSides.innerLeft, height: m.base.top - m.lidTop.inner)
    return Body(path: outer.subtracting(inner).union(base), signArea: screen)
}

/// Apple's `display` at Regular (the iMac without its chin, so the screen and the sign are bigger):
/// frame x 12.5…128.9, y 6.9…88.6 with an even 7.9 pt edge, neck 30.8 wide, rounded foot 39 wide.
/// Other weights grow the lines by half the stroke change on each side.
func imac(_ m: Metrics) -> Body {
    let d = m.stroke - 7.9
    let frame = roundedRect(12.5 - d / 2, 6.9 - d / 2, 128.9 + d / 2, 88.6 + d / 2, 9 + d / 2)
    let screen = CGRect(x: 20.4 + d / 2, y: 14.8 + d / 2, width: 100.6 - d, height: 65.9 - d)
    let opening = CGPath(roundedRect: screen, cornerWidth: max(2, 4 - d / 4), cornerHeight: max(2, 4 - d / 4), transform: nil)
    let neck = CGPath(rect: CGRect(x: 55.3 - d / 2, y: 86 + d / 2, width: 30.8 + d, height: 13.5), transform: nil)
    let footTop = 99 + d / 2, footBottom = 106.1 + d * 1.1
    let foot = roundedRect(51.2 - d, footTop, 90.2 + d, footBottom, (footBottom - footTop) / 2)
    return Body(path: frame.subtracting(opening).union(neck).union(foot), signArea: screen)
}

/// A rectangle with Apple's continuous ("squircle") corners, as on app icons. `r` is the nominal
/// radius; each corner curve starts 1.528 r from the corner.
func continuousRect(_ rect: CGRect, _ r: CGFloat) -> CGPath {
    // One corner (the top-right, y down) as offsets from the corner, then rotated to the others.
    let corner: [(CGFloat, CGFloat)] = [
        (-1.52866, 0), (-1.08849, 0), (-0.86840, 0), (-0.63149, 0.07491),
        (-0.37282, 0.16906), (-0.16906, 0.37282), (-0.07491, 0.63149),
        (0, 0.86840), (0, 1.08849), (0, 1.52866),
    ]
    let corners: [(CGPoint, (CGFloat, CGFloat) -> CGPoint)] = [
        (CGPoint(x: rect.maxX, y: rect.minY), { dx, dy in CGPoint(x: dx, y: dy) }),   // top right
        (CGPoint(x: rect.maxX, y: rect.maxY), { dx, dy in CGPoint(x: -dy, y: dx) }),  // bottom right
        (CGPoint(x: rect.minX, y: rect.maxY), { dx, dy in CGPoint(x: -dx, y: -dy) }), // bottom left
        (CGPoint(x: rect.minX, y: rect.minY), { dx, dy in CGPoint(x: dy, y: -dx) }),  // top left
    ]
    let path = CGMutablePath()
    for (i, (origin, rotate)) in corners.enumerated() {
        let pts = corner.map { dx, dy -> CGPoint in
            let v = rotate(dx * r, dy * r)
            return CGPoint(x: origin.x + v.x, y: origin.y + v.y)
        }
        if i == 0 { path.move(to: pts[0]) } else { path.addLine(to: pts[0]) }
        path.addCurve(to: pts[3], control1: pts[1], control2: pts[2])
        path.addCurve(to: pts[6], control1: pts[4], control2: pts[5])
        path.addCurve(to: pts[9], control1: pts[7], control2: pts[8])
    }
    path.closeSubpath()
    return path
}

/// The Mac mini from above: a rounded square shaped like Apple's `app` outline (7.9 pt edge at
/// Regular) but 96 pt instead of 88, so it doesn't look small next to the laptop and iMac. The
/// sign sits where the Apple logo is.
func macmini(_ m: Metrics) -> Body {
    let d = m.stroke - 7.9
    let side: CGFloat = 96 + d
    let outer = CGRect(x: 13.5 - d / 2, y: 8 - d / 2, width: side, height: side)
    let inner = outer.insetBy(dx: m.stroke, dy: m.stroke)
    let radius: CGFloat = 21.3 + d / 4
    let path = continuousRect(outer, radius).subtracting(continuousRect(inner, max(4, radius - m.stroke)))
    return Body(path: path, signArea: inner)
}

// MARK: - Signs

/// A lemniscate drawn through the middle of the screen and stroked like a symbol line.
func infinity(center: CGPoint, width: CGFloat, height: CGFloat, stroke: CGFloat) -> CGPath {
    let a = (width - stroke) / 2                     // center line half width
    let k = ((height - stroke) / 2) / (a * 0.353553) // vertical stretch: rounder loops than Bernoulli's
    let n = 72
    let points: [CGPoint] = (0..<n).map { i in
        let t = CGFloat(i) / CGFloat(n) * 2 * .pi
        let d = 1 + sin(t) * sin(t)
        return CGPoint(x: center.x + a * cos(t) / d, y: center.y + k * a * sin(t) * cos(t) / d)
    }
    // Closed Catmull-Rom spline through the samples → smooth cubic Béziers.
    let line = CGMutablePath()
    line.move(to: points[0])
    for i in 0..<n {
        let p0 = points[(i - 1 + n) % n], p1 = points[i], p2 = points[(i + 1) % n], p3 = points[(i + 2) % n]
        let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
        let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
        line.addCurve(to: p2, control1: c1, control2: c2)
    }
    line.closeSubpath()
    return line.copy(strokingWithWidth: stroke, lineCap: .round, lineJoin: .round, miterLimit: 4).normalized()
}

/// Apple's `sleep` symbol (the "Put Display to Sleep" control): a ring with a line across its
/// lower part, 69% of the way down, a little thinner than the ring.
func sleepSign(center: CGPoint, diameter: CGFloat, stroke: CGFloat) -> CGPath {
    let outer = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
    let disc = CGPath(ellipseIn: outer, transform: nil)
    let ring = disc.subtracting(CGPath(ellipseIn: outer.insetBy(dx: stroke, dy: stroke), transform: nil))
    let lineY = outer.minY + diameter * 0.69
    let thickness = stroke * 0.88
    let bar = CGPath(rect: CGRect(x: outer.minX, y: lineY - thickness / 2, width: diameter, height: thickness), transform: nil)
    return ring.union(bar.intersection(disc))
}

func sign(_ screen: Screen, in area: CGRect, weight m: Metrics) -> CGPath {
    // The sign thins with the frame at light weights but bulks up more slowly at heavy ones, so
    // its loops stay open. Sized from the area's height, or its width when that's the tighter fit
    // (the Mac mini's square top), always keeping the same proportions.
    let s = m.stroke <= 7.9 ? m.stroke * 0.886 : 7 + (m.stroke - 7.9) * 0.5
    let center = CGPoint(x: area.midX, y: area.midY)
    switch screen {
    case .infinity:
        let byHeight = 0.53 * area.height + (s - 7) * 0.8
        let byWidth = 0.8 * area.width + (s - 7)
        let width = min(byWidth, 2.06 * byHeight)
        return infinity(center: center, width: width, height: width / 2.06, stroke: s)
    case .sleep:
        return sleepSign(center: center, diameter: min(0.74 * area.height, 0.6 * area.width), stroke: min(s * 0.6, 4.2 + (s - 7) * 0.35))
    }
}

/// The whole glyph for one weight, in coordinates relative to (left margin, baseline), and its advance.
func glyph(_ m: Metrics, _ device: Device, _ screen: Screen) -> (path: CGPath, advance: CGFloat) {
    let body: Body = switch device {
    case .laptop: laptop(m)
    case .imac: imac(m)
    case .macmini: macmini(m)
    }
    let path = body.path.union(sign(screen, in: body.signArea, weight: m))
    var place: CGAffineTransform
    var advance: CGFloat
    if device == .laptop {
        place = CGAffineTransform(translationX: 0, y: -m.baseline)
        advance = m.advance
    } else {
        // Like Apple's symbols: 12.5 pt side bearings, vertically centred on the cap height.
        let box = path.boundingBoxOfPath
        place = CGAffineTransform(translationX: sideBearing - box.minX, y: -(box.midY + capHeight / 2))
        advance = box.width + 2 * sideBearing
    }
    return (path.copy(using: &place)!, advance)
}

func scaled(_ path: CGPath, by k: CGFloat) -> CGPath {
    var t = CGAffineTransform(translationX: 0, y: -capHeight / 2).scaledBy(x: k, y: k).translatedBy(x: 0, y: capHeight / 2)
    return path.copy(using: &t)!
}

// MARK: - SVG path data

func svgPath(_ path: CGPath, dx: CGFloat = 0, dy: CGFloat = 0) -> String {
    func f(_ v: CGFloat) -> String { String(format: "%.3f", Double(v)).replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression) }
    func p(_ pt: CGPoint) -> String { "\(f(pt.x + dx)) \(f(pt.y + dy))" }
    var d: [String] = []
    path.applyWithBlock { el in
        let pts = el.pointee.points
        switch el.pointee.type {
        case .moveToPoint: d.append("M\(p(pts[0]))")
        case .addLineToPoint: d.append("L\(p(pts[0]))")
        case .addQuadCurveToPoint: d.append("Q\(p(pts[0])) \(p(pts[1]))")
        case .addCurveToPoint: d.append("C\(p(pts[0])) \(p(pts[1])) \(p(pts[2]))")
        case .closeSubpath: d.append("Z")
        @unknown default: break
        }
    }
    return d.joined(separator: " ")
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let catalog = root.appendingPathComponent("Shared/Symbols.xcassets")

// MARK: - Custom symbol templates (SF Symbols template v3, static: all 27 variants)

func writeSymbol(_ device: Device, _ screen: Screen) throws {
    let name = "\(device.rawValue).\(screen.rawValue)"
    let baselines: [String: CGFloat] = ["S": 696, "M": 1126, "L": 1556]
    let guide = "fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;"
    let margin = "fill:none;stroke:#00AEEF;stroke-width:0.5;opacity:1.0;"
    var marginLines: [String] = []
    var symbolGroups: [String] = []
    for (column, m) in weights.enumerated() {
        let (path, advance) = glyph(m, device, screen)
        let columnCenter = 559 + CGFloat(column) * 297
        for (scale, k) in scales {
            let id = "\(m.name)-\(scale)"
            let width = advance * k
            let left = (columnCenter - width / 2).rounded()
            let base = baselines[scale]!
            marginLines.append("""
              <line id="left-margin-\(id)" style="\(margin)" x1="\(left)" x2="\(left)" y1="\(base - 95.21)" y2="\(base + 24.12)"/>
              <line id="right-margin-\(id)" style="\(margin)" x1="\(left + width)" x2="\(left + width)" y1="\(base - 95.21)" y2="\(base + 24.12)"/>
            """)
            symbolGroups.append("""
              <g id="\(id)">
               <path d="\(svgPath(scaled(path, by: k), dx: left, dy: base))"/>
              </g>
            """)
        }
    }
    let template = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
    <svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="3300" height="2200">
     <!--glyph: "", point size: 100.0, template writer version: "Screen Awake make-symbol"-->
     <g id="Notes">
      <rect height="2200" id="artboard" style="fill:white;opacity:1" width="3300" x="0" y="0"/>
      <text id="template-version" style="stroke:none;fill:black;font-family:sans-serif;font-size:13;text-anchor:end;" transform="matrix(1 0 0 1 3036 1933)">Template v.3.0</text>
     </g>
     <g id="Guides">
      <line id="Baseline-S" style="\(guide)" x1="263" x2="3036" y1="696" y2="696"/>
      <line id="Capline-S" style="\(guide)" x1="263" x2="3036" y1="625.541" y2="625.541"/>
      <line id="Baseline-M" style="\(guide)" x1="263" x2="3036" y1="1126" y2="1126"/>
      <line id="Capline-M" style="\(guide)" x1="263" x2="3036" y1="1055.54" y2="1055.54"/>
      <line id="Baseline-L" style="\(guide)" x1="263" x2="3036" y1="1556" y2="1556"/>
      <line id="Capline-L" style="\(guide)" x1="263" x2="3036" y1="1485.54" y2="1485.54"/>
    \(marginLines.joined(separator: "\n"))
     </g>
     <g id="Symbols">
    \(symbolGroups.joined(separator: "\n"))
     </g>
    </svg>

    """
    let symbolset = catalog.appendingPathComponent("\(name).symbolset")
    try FileManager.default.createDirectory(at: symbolset, withIntermediateDirectories: true)
    try template.write(to: symbolset.appendingPathComponent("\(name).svg"), atomically: true, encoding: .utf8)
    try """
    {
      "info" : { "author" : "xcode", "version" : 1 },
      "symbols" : [ { "filename" : "\(name).svg", "idiom" : "universal" } ]
    }

    """.write(to: symbolset.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
}

for device in Device.allCases {
    for screen in Screen.allCases { try writeSymbol(device, screen) }
}
try """
{
  "info" : { "author" : "xcode", "version" : 1 }
}

""".write(to: catalog.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

// MARK: - App icons, one per kind of Mac (Regular glyph with ∞, white on blue)
//
// App/Icons/AppIcon-<mac>.icon (Icon Composer format). The build turns each into an .icns inside the
// app, and on first launch the app gives itself the one for the Mac it's on (AppIconUpdater).

let iconPlacement: [Device: (scale: Double, dy: Double)] = [
    .laptop: (5.0, 12),  // wide and short: the base sits a little low
    .imac: (5.4, 6),
    .macmini: (5.6, 0),
]
for device in Device.allCases {
    let path = glyph(weights[3], device, .infinity).path
    let box = path.boundingBoxOfPath.insetBy(dx: -1, dy: -1)
    let icon = root.appendingPathComponent("App/Icons/AppIcon-\(device.rawValue).icon")
    try FileManager.default.createDirectory(at: icon.appendingPathComponent("Assets"), withIntermediateDirectories: true)
    let w = Int(box.width.rounded(.up)), h = Int(box.height.rounded(.up))
    try """
    <svg xmlns="http://www.w3.org/2000/svg" width="\(w)" height="\(h)" viewBox="0 0 \(w) \(h)">
     <path fill="#FFFFFF" d="\(svgPath(path, dx: -box.minX, dy: -box.minY))"/>
    </svg>

    """.write(to: icon.appendingPathComponent("Assets/glyph.svg"), atomically: true, encoding: .utf8)
    let place = iconPlacement[device]!
    try """
    {
      "fill" : {
        "automatic-gradient" : "srgb:0.00000,0.47843,1.00000,1.00000"
      },
      "groups" : [
        {
          "layers" : [
            {
              "fill-specializations" : [
                { "value" : { "solid" : "srgb:1.00000,1.00000,1.00000,1.00000" } },
                { "appearance" : "dark", "value" : { "solid" : "srgb:0.25098,0.61176,1.00000,1.00000" } }
              ],
              "image-name" : "glyph.svg",
              "name" : "glyph",
              "position" : {
                "scale" : \(place.scale),
                "translation-in-points" : [ 0, \(place.dy) ]
              }
            }
          ],
          "shadow" : { "kind" : "neutral", "opacity" : 0.5 },
          "translucency" : { "enabled" : true, "value" : 0.5 }
        }
      ],
      "supported-platforms" : {
        "squares" : "shared"
      }
    }

    """.write(to: icon.appendingPathComponent("icon.json"), atomically: true, encoding: .utf8)
}

// MARK: - The app icon as downloaded: just a screen with ∞
//
// App/AppIcon.icon is what the DMG and a fresh install show. On first launch the app swaps in the
// icon for the Mac it's on (AppIconUpdater), so this one deliberately isn't any particular Mac:
// a rounded rectangle with ordinary corners (not the Mac mini's squircle) around the sign.

do {
    let m = weights[3]
    let outer = CGRect(x: 0, y: 0, width: 132, height: 86)
    let inner = outer.insetBy(dx: m.stroke, dy: m.stroke)
    let frame = CGPath(roundedRect: outer, cornerWidth: 14, cornerHeight: 14, transform: nil)
        .subtracting(CGPath(roundedRect: inner, cornerWidth: 14 - m.stroke / 2, cornerHeight: 14 - m.stroke / 2, transform: nil))
    let path = frame.union(sign(.infinity, in: inner, weight: m))
    let box = path.boundingBoxOfPath.insetBy(dx: -1, dy: -1)
    let icon = root.appendingPathComponent("App/AppIcon.icon")
    try FileManager.default.createDirectory(at: icon.appendingPathComponent("Assets"), withIntermediateDirectories: true)
    let w = Int(box.width.rounded(.up)), h = Int(box.height.rounded(.up))
    try """
    <svg xmlns="http://www.w3.org/2000/svg" width="\(w)" height="\(h)" viewBox="0 0 \(w) \(h)">
     <path fill="#FFFFFF" d="\(svgPath(path, dx: -box.minX, dy: -box.minY))"/>
    </svg>

    """.write(to: icon.appendingPathComponent("Assets/glyph.svg"), atomically: true, encoding: .utf8)
    let json = try String(contentsOf: root.appendingPathComponent("App/Icons/AppIcon-laptop.icon/icon.json"), encoding: .utf8)
        .replacingOccurrences(of: "\"scale\" : 5.0", with: "\"scale\" : 5.0")
        .replacingOccurrences(of: "[ 0, 12.0 ]", with: "[ 0, 0 ]")
    try json.write(to: icon.appendingPathComponent("icon.json"), atomically: true, encoding: .utf8)
}

// MARK: - Preview: per Mac, Apple's symbol over ours (∞, then sleep), Ultralight → Black

guard CommandLine.arguments.count > 1 else { exit(0) }
let cell = CGSize(width: 120, height: 90)
let rows: [(apple: String, device: Device)] = [("laptopcomputer", .laptop), ("display", .imac), ("app", .macmini)]
let size = CGSize(width: cell.width * CGFloat(weights.count), height: cell.height * CGFloat(rows.count * 3))
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = size
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
NSColor(white: 0.93, alpha: 1).setFill(); CGRect(origin: .zero, size: size).fill()
let systemWeights: [NSFont.Weight] = [.ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black]
let pt: CGFloat = 50, k = pt / 100
for (r, row) in rows.enumerated() {
    let top = size.height - CGFloat(r * 3 + 1) * cell.height // y of the Apple row (flipped: bottom-up)
    for (i, m) in weights.enumerated() {
        let ref = NSImage(systemSymbolName: row.apple, accessibilityDescription: nil)!
            .withSymbolConfiguration(.init(pointSize: pt, weight: systemWeights[i], scale: .medium))!
        ref.draw(in: CGRect(x: CGFloat(i) * cell.width + (cell.width - ref.size.width) / 2, y: top + (cell.height - ref.size.height) / 2,
                            width: ref.size.width, height: ref.size.height))
        for (j, screen) in Screen.allCases.enumerated() {
            let (path, advance) = glyph(m, row.device, screen)
            ctx.saveGState()
            ctx.translateBy(x: CGFloat(i) * cell.width + (cell.width - advance * k) / 2,
                            y: top - CGFloat(j + 1) * cell.height + cell.height / 2 - capHeight * k / 2)
            ctx.scaleBy(x: k, y: -k)
            ctx.addPath(path); ctx.setFillColor(NSColor.black.cgColor); ctx.fillPath()
            ctx.restoreGState()
        }
    }
}
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
