import XCTest
@testable import MacDuoBar

final class PanelMotionTests: XCTestCase {
    func testReopeningInvalidatesClosingCompletion() {
        var motion = PanelMotion()
        let opening = motion.begin(showing: true)
        let closing = motion.begin(showing: false)
        XCTAssertTrue(motion.isClosing)
        XCTAssertFalse(motion.accepts(opening))
        let reopened = motion.begin(showing: true)
        XCTAssertFalse(motion.isClosing)
        XCTAssertFalse(motion.accepts(closing))
        XCTAssertTrue(motion.accepts(reopened))
        let finalClose = motion.begin(showing: false)
        XCTAssertFalse(motion.accepts(reopened))
        XCTAssertTrue(motion.accepts(finalClose))
    }

    func testMeasuredOffsetPreservesContentSizeAcrossDisplays() {
        for frame in [CGRect(x: 100, y: 500, width: 304, height: 340), CGRect(x: -800, y: -20, width: 304, height: 340)] {
            let hidden = PanelMotion.hiddenFrame(for: frame, reduceMotion: false)
            XCTAssertEqual(hidden.size, frame.size)
            XCTAssertEqual(hidden.origin.x, frame.origin.x - 1)
            XCTAssertEqual(hidden.origin.y, frame.origin.y + 3)
            XCTAssertEqual(PanelMotion.hiddenFrame(for: frame, reduceMotion: true), frame)
        }
    }

    func testReducedMotionOnlyFadesAndShutdownDoesNotWaitForAnimation() {
        XCTAssertEqual(PanelMotion.duration(showing: true, animated: true, reduceMotion: false), 0.24)
        XCTAssertEqual(PanelMotion.duration(showing: false, animated: true, reduceMotion: false), 0.18)
        XCTAssertEqual(PanelMotion.duration(showing: true, animated: true, reduceMotion: true), 0.1)
        XCTAssertEqual(PanelMotion.duration(showing: false, animated: false, reduceMotion: false), 0)
        XCTAssertEqual(PanelMotion.duration(showing: false, animated: false, reduceMotion: true), 0)
    }
}
