import AppKit
import QuartzCore

@MainActor
final class StatusPanel: NSPanel {
    var onCancel: (() -> Void)?
    var onDismissed: (() -> Void)?
    private var motion = PanelMotion()
    private var restingFrame = CGRect.zero
    var isClosing: Bool { motion.isClosing }

    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { onCancel?() }

    func reopen() { present(at: restingFrame) }

    func present(at frame: CGRect) {
        let revision = motion.begin(showing: true)
        restingFrame = frame
        animationBehavior = .none
        ignoresMouseEvents = false
        let firstPresentation = !isVisible
        if firstPresentation { alphaValue = 0 }
        makeKeyAndOrderFront(nil)
        if firstPresentation {
            alphaValue = 0
            setFrame(PanelMotion.hiddenFrame(for: frame, reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion), display: false)
            displayIfNeeded()
            // Commit the initial window before animating, including when AXPress dispatched the action.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.motion.accepts(revision) else { return }
                self.animate(showing: true, animated: true, revision: revision)
            }
        } else {
            animate(showing: true, animated: true, revision: revision)
        }
    }

    func dismiss(animated: Bool = true) {
        guard !isClosing || !animated else { return }
        let revision = motion.begin(showing: false)
        ignoresMouseEvents = true
        animate(showing: false, animated: animated, revision: revision)
    }

    private func animate(showing: Bool, animated: Bool, revision: Int) {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let target = showing ? restingFrame : PanelMotion.hiddenFrame(for: restingFrame, reduceMotion: reduceMotion)
        let duration = PanelMotion.duration(showing: showing, animated: animated, reduceMotion: reduceMotion)
        let finish: @MainActor @Sendable () -> Void = { [weak self] in
            guard let self, self.motion.accepts(revision) else { return }
            if !showing {
                self.close()
                self.onDismissed?()
            }
        }
        guard duration > 0 else {
            alphaValue = showing ? 1 : 0
            setFrame(target, display: false)
            finish()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = showing
                ? CAMediaTimingFunction(controlPoints: 0.25, 0, 0.1, 1)
                : CAMediaTimingFunction(controlPoints: 0.15, 0, 0.25, 1)
            animator().alphaValue = showing ? 1 : 0
            animator().setFrame(target, display: true)
        } completionHandler: {
            Task { @MainActor in finish() }
        }
    }
}
