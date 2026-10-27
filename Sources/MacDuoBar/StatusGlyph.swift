import AppKit
import CoreText

@MainActor
enum StatusGlyph {
    static let center = NSPoint(x: 24, y: 24.427)
    private static var symbols: [String: (image: NSImage, ink: NSRect)] = [:]

    static func image(layout: Layout, snapshot: Snapshot) -> NSImage {
        let powered = Position.allCases.contains { layout[$0] == .battery } && snapshot[.battery].isExternallyPowered
        let image = NSImage(size: NSSize(width: 24, height: 24), flipped: true) { _ in
            let scale: CGFloat = 0.5
            NSGraphicsContext.saveGraphicsState()
            NSAffineTransform(transform: AffineTransform(scale: scale)).concat()
            if layout.ring != .hidden {
                let value = snapshot[layout.ring].fraction
                arc(center: center, radius: 18.95, start: 135, end: 405, alpha: 0.22, powered: powered)
                if let value, value > 0 {
                    arc(center: center, radius: 18.95, start: 135, end: 135 + 270 * value, alpha: 1, powered: powered)
                }
            }
            if layout.center != .hidden {
                let reading = snapshot[layout.center]
                if let name = reading.centerSymbol, let symbol = artwork(named: name) {
                    let box = centeredFrame(imageSize: symbol.image.size, ink: symbol.ink)
                    symbol.image.draw(in: box, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
                } else {
                    let text = NSAttributedString(string: reading.number, attributes: [
                        .font: NSFont.monospacedDigitSystemFont(ofSize: 16, weight: .semibold),
                        .foregroundColor: NSColor.black
                    ])
                    let line = CTLineCreateWithAttributedString(text)
                    let path = CGMutablePath()
                    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
                        let count = CTRunGetGlyphCount(run)
                        var glyphs = [CGGlyph](repeating: 0, count: count)
                        var positions = [CGPoint](repeating: .zero, count: count)
                        CTRunGetGlyphs(run, CFRange(), &glyphs)
                        CTRunGetPositions(run, CFRange(), &positions)
                        let font = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName] as! CTFont
                        for index in 0..<count {
                            if let glyph = CTFontCreatePathForGlyph(font, glyphs[index], nil) {
                                path.addPath(glyph, transform: CGAffineTransform(translationX: positions[index].x, y: positions[index].y))
                            }
                        }
                    }
                    let bounds = path.boundingBoxOfPath
                    if let context = NSGraphicsContext.current?.cgContext {
                        context.saveGState()
                        context.translateBy(x: center.x, y: center.y)
                        context.scaleBy(x: 1, y: -1)
                        context.translateBy(x: -bounds.midX, y: -bounds.midY)
                        context.setFillColor(NSColor.black.cgColor)
                        context.addPath(path)
                        context.fillPath()
                        context.restoreGState()
                    }
                }
            }
            if layout.dots != .hidden {
                let points: [NSPoint] = [.init(x: 14.671, y: 40.668), .init(x: 20.671, y: 43.338), .init(x: 27.329, y: 43.338), .init(x: 33.329, y: 40.668)]
                for (index, point) in points.enumerated() {
                    NSColor.black.withAlphaComponent(index < snapshot[layout.dots].dotCount ? 1 : 0.22).setFill()
                    NSBezierPath(ovalIn: NSRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)).fill()
                }
            }
            if powered, let bolt = artwork(named: "bolt.fill") {
                let box = centeredFrame(imageSize: bolt.image.size, ink: bolt.ink,
                                        center: NSPoint(x: center.x, y: 6.32), maximum: NSSize(width: 6.4, height: 10))
                bolt.image.draw(in: box, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            }
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func artwork(named name: String) -> (image: NSImage, ink: NSRect)? {
        if let cached = symbols[name] { return cached }
        guard let vector = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: 68, weight: .semibold)),
              let cgImage = vector.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let image = NSImage(cgImage: cgImage, size: vector.size)
        guard let ink = inkBounds(of: image) else { return nil }
        symbols[name] = (image, ink)
        return (image, ink)
    }

    static func centeredFrame(imageSize: NSSize, ink: NSRect, center: NSPoint = Self.center,
                              maximum: NSSize = NSSize(width: 24, height: 20)) -> NSRect {
        let scale = min(maximum.width / ink.width, maximum.height / ink.height)
        return NSRect(x: center.x - ink.midX * scale, y: center.y - ink.midY * scale,
                      width: imageSize.width * scale, height: imageSize.height * scale)
    }

    // SF Symbols include layout padding; cache system-rendered artwork and align its visible bounds.
    static func inkBounds(of image: NSImage) -> NSRect? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        var bounds = NSRect.null
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.1 {
                bounds = bounds.union(NSRect(x: x, y: y, width: 1, height: 1))
            }
        }
        guard !bounds.isNull else { return nil }
        let xScale = image.size.width / CGFloat(bitmap.pixelsWide)
        let yScale = image.size.height / CGFloat(bitmap.pixelsHigh)
        return NSRect(x: bounds.minX * xScale, y: bounds.minY * yScale, width: bounds.width * xScale, height: bounds.height * yScale)
    }

    private static func arc(center: NSPoint, radius: CGFloat, start: Double, end: Double, alpha: CGFloat,
                            powered: Bool) {
        // The captured compact charging state reserves the top of the ring for the bolt.
        let segments = powered ? [(start, min(end, 255)), (max(start, 285), end)] : [(start, end)]
        for (start, end) in segments where end > start {
            let path = NSBezierPath()
            path.lineWidth = 3.1
            path.lineCapStyle = .round
            path.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
            NSColor.black.withAlphaComponent(alpha).setStroke()
            path.stroke()
        }
    }
}
