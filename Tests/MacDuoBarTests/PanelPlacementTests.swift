import XCTest
@testable import MacDuoBar

final class PanelPlacementTests: XCTestCase {
    func testMenuPanelCentersUnderAnchorWithoutCoveringMenuBar() {
        let anchor = CGRect(x: 900, y: 878, width: 24, height: 22)
        let frame = PanelPlacement.frame(size: CGSize(width: 356, height: 404), anchor: anchor,
                                        visibleFrame: CGRect(x: 0, y: 40, width: 1440, height: 838), fromMenuBar: true)
        XCTAssertEqual(frame.midX, anchor.midX)
        XCTAssertLessThanOrEqual(frame.maxY, anchor.minY)
    }

    func testRightEdgeAndNegativeCoordinateDisplayStayOnScreen() {
        let visible = CGRect(x: -1440, y: -300, width: 1440, height: 860)
        let frame = PanelPlacement.frame(size: CGSize(width: 356, height: 404), anchor: CGRect(x: -20, y: 560, width: 20, height: 24), visibleFrame: visible, fromMenuBar: true)
        XCTAssertTrue(visible.insetBy(dx: 8, dy: 6).contains(frame))
        XCTAssertEqual(frame.maxX, -8)
    }

    func testSettingsPreviewUsesItsOwnWindowAnchor() {
        let anchor = CGRect(x: 100, y: 100, width: 440, height: 430)
        let frame = PanelPlacement.frame(size: CGSize(width: 356, height: 404), anchor: anchor,
                                        visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900), fromMenuBar: false)
        XCTAssertEqual(frame.minX, anchor.maxX)
        XCTAssertEqual(frame.maxY, anchor.maxY)
    }

    func testOversizedPanelIsConstrainedToVisibleFrame() {
        let visible = CGRect(x: 0, y: 0, width: 320, height: 400)
        let frame = PanelPlacement.frame(size: CGSize(width: 356, height: 404), anchor: CGRect(x: 0, y: 400, width: 24, height: 24), visibleFrame: visible, fromMenuBar: true)
        XCTAssertEqual(frame, visible.insetBy(dx: 8, dy: 6))
    }

    func testCardSurfaceMatchesMeasuredMenuBarGapAndRightMargin() {
        let visible = CGRect(x: 0, y: 54, width: 1512, height: 895)
        let frame = PanelPlacement.frame(size: CGSize(width: 304, height: 340), anchor: CGRect(x: 1490, y: 949, width: 22, height: 33), visibleFrame: visible, fromMenuBar: true)
        XCTAssertEqual(982 - (frame.maxY - ControlCenterStyle.padding), 45)
        XCTAssertEqual(1512 - (frame.maxX - ControlCenterStyle.padding), 14)
    }
}
