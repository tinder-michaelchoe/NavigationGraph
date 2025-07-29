import UIKit

/// A simple view controller that displays its node identifier and
/// invokes a completion callback when the user taps the "Next"
/// button.  The background colour is passed in during
/// initialization to visually distinguish each screen.
final class NodeViewController: UIViewController {
    private let nodeId: String
    private let colour: UIColor
    /// A closure that the coordinator sets to be called when the
    /// user has finished interacting with this screen.  The
    /// parameter carries the data returned from the screen.  For
    /// simple screens with `Void` data, pass `()` to this closure.
    var onComplete: ((Any) -> Void)?

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

    override func viewDidLoad() {
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
    override func viewDidAppear(_ animated: Bool) {
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
    override func viewWillDisappear(_ animated: Bool) {
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

// Conform NodeViewController to NavigableViewController so that
// NavigationController can set its onComplete callback.
extension NodeViewController: NavigableViewController {}













/*
//
//  ExampleUIKitNavigation.swift
//
//  This file demonstrates how to use the type‑safe NavigationGraph and
//  NavigationController with real UIKit view controllers.  Each
//  screen is represented by a `NodeViewController` that displays its
//  identifier and a unique background colour.  When the user taps
//  "Next", the screen signals completion and the navigation
//  controller consults the graph to determine the next destination.
//
//  You can drop this code into an Xcode iOS project to see the
//  navigation flow in action.  Note that this example relies on
//  Swift's async/await concurrency, so it requires iOS 15 or later.

import UIKit

/// A simple view controller that displays its node identifier and
/// invokes a completion callback when the user taps the "Next"
/// button.  The background colour is passed in during
/// initialization to visually distinguish each screen.
final class NodeViewController: UIViewController {
    private let nodeId: String
    private let colour: UIColor
    /// A closure that the coordinator sets to be called when the
    /// user has finished interacting with this screen.  In this
    /// example, tapping the "Next" button triggers the callback.
    var onComplete: (() -> Void)?

    init(nodeId: String, colour: UIColor) {
        self.nodeId = nodeId
        self.colour = colour
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = colour
        // Create a label showing the node identifier.
        let label = UILabel()
        label.text = nodeId
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        // Create a "Next" button that triggers the completion.
        let button = UIButton(type: .system)
        button.setTitle("Next", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .black.withAlphaComponent(0.3)
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        view.addSubview(button)
        // Layout the label and button.
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20)
        ])
    }

    @objc private func nextTapped() {
        onComplete?()
    }
}

/// A coordinator that wires together the NavigationGraph, the
/// type‑safe NavigationController and a UINavigationController.  It
/// constructs the graph, defines the presenter closure that
/// displays each screen, and starts the navigation flow from the
/// designated start node.
final class AppCoordinator {
    /// The UIKit navigation controller that presents each screen.
    private let uiNavigationController: UINavigationController
    /// The type‑safe graph describing the flow.
    private let graph: NavigationGraph
    /// The type‑safe controller that orchestrates navigation.
    private let navController: NavigationController
    /// A mapping from node identifiers to distinct colours for
    /// demonstration purposes.
    private let colours: [String: UIColor] = [
        "home": .systemBlue,
        "profile": .systemGreen,
        "settings": .systemOrange,
        "welcome": .systemPurple,
        "register": .systemRed
    ]

    init() {
        self.uiNavigationController = UINavigationController()
        self.graph = NavigationGraph()
        // Define your nodes.  Each one uses Void as its data type
        // for simplicity.  If your screens require data, replace
        // Void with a concrete type.
        let home = ScreenNode<Void>("home")
        let profile = ScreenNode<Void>("profile")
        let settings = ScreenNode<Void>("settings")
        let welcome = ScreenNode<Void>("welcome")
        let register = ScreenNode<Void>("register")
        // Register nodes with the graph.
        graph.addNode(home)
        graph.addNode(profile)
        graph.addNode(settings)
        // Build an onboarding subgraph.
        let onboardingGraph = NavigationGraph()
        onboardingGraph.addNode(welcome)
        onboardingGraph.addNode(register)
        onboardingGraph.addEdge(Edge(from: welcome, to: register, transition: .push) { _ in return () })
        let onboarding = NavSubgraph(id: "onboarding", graph: onboardingGraph, start: welcome)
        graph.addSubgraph(onboarding)
        // Register edges in the main graph.
        graph.addEdge(Edge(from: home, to: profile, transition: .push) { _ in return () })
        graph.addEdge(Edge(from: profile, to: settings, transition: .modal) { _ in return () })
        graph.addEdge(Edge(from: settings, to: onboarding, transition: .modal) { _ in return () })
        // Define the presenter closure.  It receives an erased node and
        // arbitrary data, creates and displays the appropriate view
        // controller, waits for the user to finish, and returns the
        // (unchanged) data.  For nested subgraphs, the graph will
        // automatically handle internal navigation, so the presenter
        // is never invoked with a subgraph node.
        let presenter: (AnyNavNode, Any) async -> Any = { [weak self] node, data in
            // Skip presentation for subgraphs (they are handled
            // automatically by NavigationController).
            if node.subgraphWrapper != nil {
                return data
            }
            guard let self = self else { return data }
            // Lookup a colour for this node or use a default.
            let colour = self.colours[node.id] ?? .darkGray
            // Use Swift concurrency to wait until the user taps "Next".
            return await withCheckedContinuation { continuation in
                let vc = NodeViewController(nodeId: node.id, colour: colour)
                vc.onComplete = {
                    continuation.resume(returning: data)
                }
                // Decide how to present the view controller.  For this
                // example we always push onto the navigation stack.
                DispatchQueue.main.async {
                    self.uiNavigationController.pushViewController(vc, animated: true)
                }
            }
        }
        // Create the navigation controller with the graph and presenter.
        self.navController = NavigationController(graph: graph, presenter: presenter)
    }

    /// Starts the flow by setting the UIKit navigation controller as
    /// the root view controller and invoking the graph's start node.
    func start(in window: UIWindow) {
        window.rootViewController = uiNavigationController
        window.makeKeyAndVisible()
        // Kick off the navigation on a background task.  The
        // navigation controller will push the first view controller
        // asynchronously when the task starts.
        let home = ScreenNode<Void>("home")
        Task {
            await navController.start(at: home, with: ())
        }
    }
}

// Usage:
// In your AppDelegate or SceneDelegate, create an instance of
// `AppCoordinator`, pass the window to `start(in:)`, and store the
// coordinator as a property to keep it alive.
*/
