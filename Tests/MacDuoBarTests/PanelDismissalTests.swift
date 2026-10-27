import XCTest
@testable import MacDuoBar

final class PanelDismissalTests: XCTestCase {
    private let button = CGRect(x: -120, y: 949, width: 24, height: 26)

    func testSameStatusButtonClickIsLeftToToggleAction() {
        XCTAssertFalse(PanelDismissal.shouldClose(primaryMouseDown: true, location: CGPoint(x: -108, y: 962), statusButtonFrame: button))
    }

    func testOutsideClickAndMissingButtonStillDismiss() {
        XCTAssertTrue(PanelDismissal.shouldClose(primaryMouseDown: true, location: CGPoint(x: -80, y: 962), statusButtonFrame: button))
        XCTAssertTrue(PanelDismissal.shouldClose(primaryMouseDown: true, location: CGPoint(x: -108, y: 962), statusButtonFrame: nil))
    }

    func testKeyboardFocusLossOrRightClickDismissesEvenWhenPointerHoversOverIcon() {
        XCTAssertTrue(PanelDismissal.shouldClose(primaryMouseDown: false, location: CGPoint(x: -108, y: 962), statusButtonFrame: button))
    }
}
