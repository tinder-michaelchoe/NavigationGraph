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

struct User {
    let name: String = "Frank"
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
        "register": .systemRed,
        "directRegister": .systemTeal
    ]

    init() {
        self.uiNavigationController = UINavigationController()
        self.graph = NavigationGraph()
        
        let home = ScreenNode<Void, WelcomeViewController.WelcomeResult>("home") { _ in
            return WelcomeViewController()
        }
        
        let signinGraph = NavigationGraph()
        
        let signinHome = ScreenNode<Void, String?>("signinHome") { _ in
            return SigninViewController()
        }
        
        let forgotPassword = ScreenNode<String?, Void>("forgotPassword") { possibleEmail in
            return ForgotPasswordViewController(initialEmailAddress: possibleEmail)
        }
        
        signinGraph.addNode(signinHome)
        signinGraph.addNode(forgotPassword)
        signinGraph.addEdge(Edge(
            from: signinHome,
            to: forgotPassword,
            transition: .push,
            transform: { possibleEmail in
                return possibleEmail ?? ""
            }
        ))
        let signInSubgraph = NavSubgraph(id: "signIn", graph: signinGraph, start: signinHome)
        graph.addSubgraph(signInSubgraph)
        graph.addEdge(Edge(
            from: home,
            to: signInSubgraph,
            transition: .push,
            predicate: { $0 == .signIn },
            transform: { _ in return () }
        ))
        
        // The profile screen returns a Bool indicating which branch
        // should be taken.  We use Bool instead of Void to allow
        // conditional navigation based on user or system state.
        let profile = ScreenNode<User, Bool>("profile") { input in
            return NodeViewController(nodeId: "profile", colour: .systemBlue)
        }
        let settings = ScreenNode<Void, Void>("settings") { _ in
            return NodeViewController(nodeId: "Settings from Factory", colour: .systemGreen)
        }
        let welcome = ScreenNode<Void, Void>("welcome") { _ in
            return NodeViewController(nodeId: "Welcome from Factory", colour: .systemOrange)
        }
        let register = ScreenNode<Void, Void>("register") { _ in
            return NodeViewController(nodeId: "Register from Factory", colour: .systemPurple)
        }

        graph.addNode(home)
        graph.addNode(profile)
        graph.addNode(settings)
        graph.addNode(register)
        
        // Build an onboarding subgraph.
        let onboardingGraph = NavigationGraph()
        onboardingGraph.addNode(welcome)
        onboardingGraph.addNode(register)
        onboardingGraph.addEdge(Edge(from: welcome, to: register, transition: .push) { _ in return () })
        let onboarding = NavSubgraph(id: "onboarding", graph: onboardingGraph, start: welcome)
        graph.addSubgraph(onboarding)
        // Register edges in the main graph.
        // Transform from home (Void) to profile (Bool).  Provide a
        // default value; the actual decision will be produced by the
        // profile screen itself.
        graph.addEdge(Edge(from: home, to: profile, transition: .push) { _ in return User() })
        // When profile completes with a value of true, navigate to
        // settings modally.  The predicate evaluates the Bool.
        graph.addEdge(Edge(from: profile, to: settings, transition: .modal, predicate: { value in value }) { _ in return () })
        // When profile completes with a value of false, navigate
        // directly to registration.  Use a predicate that returns
        // true when the value is false.
        graph.addEdge(Edge(from: profile, to: register, transition: .push, predicate: { value in !value }) { _ in return () })
        graph.addEdge(Edge(from: settings, to: onboarding, transition: .modal) { _ in return () })

        self.navController = NavigationController(
            graph: graph,
            navigationController: uiNavigationController
        )
    }

    /// Starts the flow by setting the UIKit navigation controller as
    /// the root view controller and invoking the graph's start node.
    func start(in window: UIWindow) {
        window.rootViewController = uiNavigationController
        window.makeKeyAndVisible()
        // Kick off the navigation synchronously.  The navigation
        // controller maintains its own stack and does not rely on
        // async/await.
        let home = ScreenNode<Void, Void>("home")
        navController.start(at: home, with: ())
    }
}
