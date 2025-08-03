import UIKit

final public class NodeViewController: UIViewController, NavigableViewController {
    private let nodeId: String
    private let colour: UIColor

    public var onComplete: ((Any) -> Void)?

    /// Tracks whether the completion callback has already been
    /// invoked.  This prevents the continuation from being resumed
    /// more than once if the view is dismissed before the user taps
    /// "Next".  See `viewWillDisappear` for details.
    private var hasCompleted = false

    init(nodeId: String, colour: UIColor) {
        self.nodeId = nodeId
        self.colour = colour
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = colour
        // Create a label showing the node identifier.
        let label = UILabel()
        label.text = nodeId
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        view.addAutolayoutSubview(label)
        // Create a "Next" button that triggers the completion.
        let button = UIButton(type: .system)
        button.setTitle("Next", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .black.withAlphaComponent(0.3)
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        button.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        view.addAutolayoutSubview(button)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20)
        ])
    }

    @objc private func nextTapped() {
        // Guard against multiple invocations.  When the user taps
        // "Next", mark the screen as completed and invoke the
        // callback.  If this method is called again (which should
        // not happen), the callback will not be invoked a second
        // time.
        guard !hasCompleted else { return }
        hasCompleted = true
        // For the profile screen we simulate a condition by passing
        // a random boolean.  Other screens return Void.
        if nodeId == "profile" {
            onComplete?(Bool.random())
        } else {
            onComplete?(())
        }
    }

    /// Reset the completion flag whenever the view appears.  This
    /// ensures that the user can tap "Next" multiple times when
    /// navigating back and forth through the stack.  Without this
    /// reset, a screen that was previously completed would remain
    /// disabled on subsequent appearances.
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Always allow the screen to complete again after it
        // reappears.  Do not reset the flag during animations to
        // avoid re‑entrant completion while in transition.
        hasCompleted = false
    }

    /// If the user navigates back (either by tapping the back
    /// button or via a swipe gesture), this view controller will be
    /// removed from the navigation stack without the "Next" button
    /// ever being tapped.  In the event‑driven version of
    /// `NavigationController` we simply mark the screen as
    /// completed here without invoking the completion callback.  The
    /// navigation controller's delegate will handle the pop and
    /// update its internal state accordingly.
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Only trigger completion if the view is being removed from
        // its parent or dismissed.  If we're simply covering it with
        // another view controller (e.g. a modal), we still want the
        // original onComplete to fire when the user eventually taps
        // "Next".
        if (isMovingFromParent || isBeingDismissed) && !hasCompleted {
            // The view controller is being popped or dismissed.  We do
            // not trigger the completion callback here.  Leave
            // hasCompleted unchanged so that the user can tap
            // "Next" again when returning to this screen.
        }
    }
}
