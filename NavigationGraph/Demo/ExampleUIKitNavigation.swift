//
//  ExampleUIKitNavigation.swift
//

import UIKit

struct User {
    let name: String = "Frank"
}

final class AppCoordinator {

    private let uiNavigationController: UINavigationController
    private let navController: NavigationController

    init() {
        self.uiNavigationController = UINavigationController()
        
        let graph = NavigationGraph()
        let nodeRegistry = NodeRegistry()
        
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

        let gender = GenderNode()
        graph.addNode(gender)

        let beyondBinary = BeyondBinaryNode()
        graph.addNode(beyondBinary)

        graph.addEdge(Edge(
            from: welcome,
            to: gender,
            transition: .push,
            predicate: {
                $0 == .next
            },
            transform: { _ in
                return nil
            }
        ))

        graph.addEdge(Edge(
            from: gender,
            to: beyondBinary,
            transition: .push,
            predicate: {
                $0 == .beyondBinary
            }
        ))

        graph.addEdge(Edge(
            from: beyondBinary,
            to: gender,
            transition: .push,
            predicate: { _ in
                return true
            },
            transform: { beyondBinaryResult in
                switch beyondBinaryResult {
                case .next(let selectedIdentity):
                    return GenderViewController.InitialState(
                        beyondBinaryDetail: selectedIdentity,
                        gender: "Beyond Binary",
                        name: nil
                    )
                case .signIn:
                    return nil
                }
            }
        ))

        print("\(graph.prettyPrintOutline(from: "WelcomeNode"))")

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
