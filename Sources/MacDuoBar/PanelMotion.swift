import Foundation

struct PanelMotion {
    static let openingDuration = 0.24
    static let closingDuration = 0.18
    private(set) var isClosing = false
    private(set) var revision = 0

    mutating func begin(showing: Bool) -> Int {
        revision += 1
        isClosing = !showing
        return revision
    }

    func accepts(_ revision: Int) -> Bool { self.revision == revision }

    static func hiddenFrame(for frame: CGRect, reduceMotion: Bool) -> CGRect {
        reduceMotion ? frame : frame.offsetBy(dx: -1, dy: 3)
    }

    static func duration(showing: Bool, animated: Bool, reduceMotion: Bool) -> TimeInterval {
        guard animated else { return 0 }
        return reduceMotion ? 0.1 : showing ? openingDuration : closingDuration
    }
}
