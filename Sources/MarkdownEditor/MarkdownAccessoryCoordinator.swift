import UIKit

final class MarkdownAccessoryCoordinator: NSObject {
    private weak var hostView: UIView?
    private weak var scrollView: UIScrollView?
    private weak var textView: UITextView?
    private weak var accessoryView: MarkdownCommandBarInputView?

    private var keyboardObserver: NSObjectProtocol?
    private var displayLink: CADisplayLink?
    private var isTrackingInteractiveDismiss = false

    init(
        hostView: UIView,
        scrollView: UIScrollView,
        textView: UITextView,
        accessoryView: MarkdownCommandBarInputView
    ) {
        self.hostView = hostView
        self.scrollView = scrollView
        self.textView = textView
        self.accessoryView = accessoryView
        super.init()
        observeKeyboardChanges()
        scrollView.panGestureRecognizer.addTarget(self, action: #selector(handlePanGesture(_:)))
        applyCurrentInsets(animated: false)
    }

    deinit {
        if let keyboardObserver {
            NotificationCenter.default.removeObserver(keyboardObserver)
        }
        displayLink?.invalidate()
    }

    func updateTrackedScrollView(_ scrollView: UIScrollView) {
        accessoryView?.trackedScrollView = scrollView
        reloadAccessoryIfNeeded()
    }

    func refreshInsets() {
        applyCurrentInsets(animated: false)
    }

    private func observeKeyboardChanges() {
        keyboardObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleKeyboardFrameChange(notification)
        }
    }

    private func handleKeyboardFrameChange(_ notification: Notification) {
        guard let hostView, let scrollView else { return }

        let userInfo = notification.userInfo ?? [:]
        let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.25
        let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 7
        let options = UIView.AnimationOptions(rawValue: curveValue << 16)

        let targetBottomInset = targetInset(from: notification)
        UIView.animate(withDuration: duration, delay: 0, options: [options, .beginFromCurrentState]) {
            guard hostView.window != nil else { return }
            self.applyInsets(bottom: targetBottomInset, to: scrollView)
            hostView.layoutIfNeeded()
        }

        DispatchQueue.main.async { [weak self] in
            self?.applyCurrentInsets(animated: false)
        }
    }

    private func targetInset(from notification: Notification) -> CGFloat {
        guard
            let hostView,
            let window = hostView.window,
            let accessoryView,
            let userInfo = notification.userInfo,
            let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else {
            return currentBottomInset()
        }

        let convertedEndFrame = hostView.convert(endFrame, from: window.screen.coordinateSpace)
        let keyboardOverlap = max(0, hostView.bounds.maxY - convertedEndFrame.minY)
        let keyboardIsHidden = convertedEndFrame.minY >= hostView.bounds.maxY - 1
        if keyboardIsHidden || textView?.isFirstResponder != true {
            return 0
        }

        return keyboardOverlap + accessoryView.intrinsicContentSize.height
    }

    private func currentBottomInset() -> CGFloat {
        guard
            let hostView,
            let window = hostView.window,
            let accessoryView,
            textView?.isFirstResponder == true
        else {
            return 0
        }

        let accessoryFrame = accessoryView.convert(accessoryView.bounds, to: window)
        let hostFrame = hostView.convert(hostView.bounds, to: window)
        return max(0, hostFrame.maxY - accessoryFrame.minY)
    }

    private func applyCurrentInsets(animated: Bool) {
        guard let scrollView else { return }
        let updates = {
            self.applyInsets(bottom: self.currentBottomInset(), to: scrollView)
        }

        if animated {
            UIView.animate(withDuration: 0.2, delay: 0, options: .beginFromCurrentState, animations: updates)
        } else {
            updates()
        }
    }

    private func applyInsets(bottom: CGFloat, to scrollView: UIScrollView) {
        let clampedBottom = max(0, bottom)
        if abs(scrollView.contentInset.bottom - clampedBottom) < 0.5,
           abs(scrollView.verticalScrollIndicatorInsets.bottom - clampedBottom) < 0.5 {
            return
        }

        scrollView.contentInset.bottom = clampedBottom
        scrollView.verticalScrollIndicatorInsets.bottom = clampedBottom
    }

    private func reloadAccessoryIfNeeded() {
        guard textView?.isFirstResponder == true else { return }
        textView?.reloadInputViews()
    }

    @objc
    private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard textView?.isFirstResponder == true else {
            stopInteractiveTracking()
            return
        }

        switch gesture.state {
        case .began, .changed:
            startInteractiveTrackingIfNeeded()
        default:
            stopInteractiveTracking()
            DispatchQueue.main.async { [weak self] in
                self?.applyCurrentInsets(animated: false)
            }
        }
    }

    private func startInteractiveTrackingIfNeeded() {
        guard !isTrackingInteractiveDismiss else { return }
        isTrackingInteractiveDismiss = true

        let displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLinkTick))
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
    }

    private func stopInteractiveTracking() {
        isTrackingInteractiveDismiss = false
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc
    private func handleDisplayLinkTick() {
        applyCurrentInsets(animated: false)
    }
}
