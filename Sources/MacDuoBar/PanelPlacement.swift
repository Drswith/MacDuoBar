import Foundation

enum PanelPlacement {
    static func frame(size: CGSize, anchor: CGRect, visibleFrame: CGRect, fromMenuBar: Bool) -> CGRect {
        let usable = visibleFrame.insetBy(dx: 8, dy: 6)
        let width = min(size.width, usable.width)
        let height = min(size.height, usable.height)
        let x = fromMenuBar ? anchor.midX - width / 2 : anchor.maxX
        let y = fromMenuBar ? anchor.minY - height : anchor.maxY - height
        return CGRect(x: min(max(x, usable.minX), usable.maxX - width),
                      y: min(max(y, usable.minY), usable.maxY - height), width: width, height: height)
    }
}
