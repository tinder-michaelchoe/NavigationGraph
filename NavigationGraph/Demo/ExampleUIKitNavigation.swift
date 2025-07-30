//
//  ExampleUIKitNavigation.swift
//

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
    //private let graph: NavigationGraph
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
        //self.graph = NavigationGraph()
        
        let graph = NavigationGraph()
        let nodeRegistry = NodeRegistry()
        
        //let welcome = WelcomeNode()
        //graph.addNode(welcome)
        
        let welcome = WelcomeNode()
        graph.addNode(welcome)
        nodeRegistry.register(welcome)
        
        // Sign In Subgraph
        let signinGraph = NavigationGraph()
        let signinHome = SignInHomeNode()
        let forgotPassword = ForgotPasswordNode()
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
        let signInSubgraph = NavSubgraph(id: "signInSubgraph", graph: signinGraph, start: signinHome)
        graph.addSubgraph(signInSubgraph)
        
        nodeRegistry.register(signInSubgraph)

        graph.addEdge(Edge(
            from: welcome,
            to: signInSubgraph,
            transition: .push,
            predicate: { $0 == .signIn }
        ))
        
        let profile = ScreenNode<User, Bool>("profile") { input in
            return NodeViewController(nodeId: "profile", colour: .systemBlue)
        }
        let settings = ScreenNode<Void, Void>("settings") { _ in
            return NodeViewController(nodeId: "Settings from Factory", colour: .systemGreen)
        }
        let register = ScreenNode<Void, Void>("register") { _ in
            return NodeViewController(nodeId: "Register from Factory", colour: .systemPurple)
        }

        graph.addNode(profile)
        graph.addNode(settings)
        graph.addNode(register)
        
        // Build an onboarding subgraph.
        let onboardingGraph = NavigationGraph()
        onboardingGraph.addNode(welcome)
        onboardingGraph.addNode(register)
        onboardingGraph.addEdge(Edge(from: welcome, to: register, transition: .push))
        let onboarding = NavSubgraph(id: "onboarding", graph: onboardingGraph, start: welcome)
        graph.addSubgraph(onboarding)
        // Register edges in the main graph.
        // Transform from home (Void) to profile (Bool).  Provide a
        // default value; the actual decision will be produced by the
        // profile screen itself.
        graph.addEdge(Edge(from: welcome, to: profile, transition: .push) { _ in return User() })
        // When profile completes with a value of true, navigate to
        // settings modally.  The predicate evaluates the Bool.
        graph.addEdge(Edge(from: profile, to: settings, transition: .modal, predicate: { value in value }))
        // When profile completes with a value of false, navigate
        // directly to registration.  Use a predicate that returns
        // true when the value is false.
        graph.addEdge(Edge(from: profile, to: register, transition: .push, predicate: { value in !value }))
        graph.addEdge(Edge(from: settings, to: onboarding, transition: .modal))

        self.navController = NavigationController(
            graph: graph,
            nodeRegistry: nodeRegistry,
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
        //let home = ScreenNode<Void, Void>("home")
        navController.start(at: WelcomeNode(), with: ())
    }
}

/*
// Convenience functions for working with NodeRegistry
extension AppCoordinator {
    func addEdge<From: NavNode, To: NavNode>(
        from: From.Type,
        to: To.Type,
        transition: TransitionType,
        predicate: ((From.OutputType) -> Bool)? = nil,
        transform: @escaping (From.OutputType) -> To.InputType
    ) {
        let edge = Edge<From, To>(
            from: nodeRegistry.resolve(from),
            to: nodeRegistry.resolve(to),
            transition: transition,
            predicate: predicate,
            transform: transform
        )
        graph.addEdge(edge)
    }
}
*/
