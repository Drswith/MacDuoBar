import Foundation

enum PanelDismissal {
    static func shouldClose(primaryMouseDown: Bool, location: CGPoint, statusButtonFrame: CGRect?) -> Bool {
        // The status-button action must receive the still-open panel so it can toggle it closed.
        !(primaryMouseDown && statusButtonFrame?.contains(location) == true)
    }
}
