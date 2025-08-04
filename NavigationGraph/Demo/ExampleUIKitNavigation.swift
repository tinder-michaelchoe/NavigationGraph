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

        let welcome = WelcomeNode()
        graph.addNode(welcome)

        let oneShotErrorNode = OneShotAlertNode()
        graph.addNode(oneShotErrorNode)

        // Sign In Subgraph
        let signinGraph = NavigationGraph()
        let signinHome = SignInHomeNode()
        let forgotPassword = ForgotPasswordNode()
        signinGraph.addNode(signinHome)
        signinGraph.addNode(forgotPassword)
        signinGraph.addNode(oneShotErrorNode)

        signinGraph.addEdge(Edge(
            from: signinHome,
            to: forgotPassword,
            transition: .push,
            predicate: { result in
                switch result {
                case .forgotPassword(_):
                    return true
                case .signIn:
                    return false
                }
            },
            transform: { result in
                guard case let SignInViewController.SignInResult.forgotPassword(possibleEmail) = result else {
                    return ""
                }
                return possibleEmail
            }
        ))

        signinGraph.addEdge(Edge(
            from: forgotPassword,
            to: oneShotErrorNode,
            transition: .modal,
            predicate: { _ in true },
            transform: { _ in
                return ("Check your email", "We sent a password reset link.")
            }
        ))

        signinGraph.addEdge(Edge(
            from: oneShotErrorNode,
            to: forgotPassword,
            transition: .none,
            predicate: { _ in true },
            transform: { _ in
                return nil
            }
        ))

        let signInSubgraph = NavSubgraph(id: "signInSubgraph", graph: signinGraph, start: signinHome)
        graph.addSubgraph(signInSubgraph)
        
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

        graph.addEdge(Edge(
            from: gender,
            to: oneShotErrorNode,
            transition: .modal,
            predicate: { result in
                switch result {
                case .error:
                    return true
                default:
                    return false
                }
            },
            transform: { genderResult in
                switch genderResult {
                case .error(let title, let message):
                    return (title, message)
                default:
                    return ("", "")
                }
            }
        ))

        graph.addEdge(Edge(
            from: oneShotErrorNode,
            to: gender,
            transition: .none,
            predicate: { _ in
                true
            },
            transform: {
                return nil
            }
        ))

        let genderLearnMore = GenderLearnMoreNode()
        graph.addNode(genderLearnMore)

        graph.addEdge(Edge(
            from: gender,
            to: genderLearnMore,
            transition: .modal,
            predicate: { result in
                result == .learnMore
            }
        ))

        let photos = PhotosNode()
        let photosSelector = PhotosSelectorNode()
        let map = MapNode()

        // MARK: - Photo Selector Subgraph

        let photoSelectorGraph = NavigationGraph()
        photoSelectorGraph.addNode(photos)
        photoSelectorGraph.addNode(photosSelector)

        photoSelectorGraph.addEdge(Edge(
            from: photos,
            to: photosSelector,
            transition: .modal,
            predicate: { result in
                return result == .photoSelector
            }
        ))

        photoSelectorGraph.addEdge(Edge(
            from: photosSelector,
            to: photos,
            transition: .dismiss,
            predicate: { _ in
                true
            }
        ))

        let photoSelectorSubgraph = NavSubgraph(id: "photoSelector", graph: photoSelectorGraph, start: photos)

        // MARK: - Photo to Map Subgraph

        let photosToMapGraph = NavigationGraph()
        photosToMapGraph.addNode(map)
        photosToMapGraph.addSubgraph(photoSelectorSubgraph)

        photosToMapGraph.addEdge(Edge(
            from: photoSelectorSubgraph,
            to: map,
            transition: .push,
            predicate: { _ in
                true
            }
        ))

        let photosToMapSubgraph = NavSubgraph(id: "photosToMap", graph: photosToMapGraph, start: photoSelectorSubgraph)
        graph.addSubgraph(photosToMapSubgraph)

        graph.addEdge(Edge(
            from: gender,
            to: photosToMapSubgraph,
            transition: .push,
            predicate: { result in
                guard
                    case let GenderViewController.GenderResult.next(gender) = result,
                    gender == "Woman" || gender == "Beyond Binary"
                else {
                    return false
                }
                return true
            }
        ))

        // MARK: - Map to Photo Subgraph

        let mapToPhotosGraph = NavigationGraph()
        mapToPhotosGraph.addNode(map)
        mapToPhotosGraph.addSubgraph(photoSelectorSubgraph)

        mapToPhotosGraph.addEdge(Edge(
            from: map,
            to: photoSelectorSubgraph,
            transition: .push,
            predicate: { _ in
                true
            }
        ))
        
        let mapToPhotosSubgraph = NavSubgraph(id: "mapToPhotos", graph: mapToPhotosGraph, start: map)
        graph.addSubgraph(mapToPhotosSubgraph)

        graph.addEdge(Edge(
            from: gender,
            to: mapToPhotosSubgraph,
            transition: .push,
            predicate: { result in
                guard
                    case let GenderViewController.GenderResult.next(gender) = result,
                    gender == "Man"
                else {
                    return false
                }
                return true
            }
        ))

        let end = EndNode()
        graph.addNode(end)

        graph.addEdge(Edge(
            from: mapToPhotosSubgraph,
            to: end,
            transition: .push,
            predicate: { _ in true }
        ))

        graph.addEdge(Edge(
            from: photosToMapSubgraph,
            to: end,
            transition: .push,
            predicate: { _ in true }
        ))

        graph.addEdge(Edge(
            from: signInSubgraph,
            to: end,
            transition: .push,
            predicate: { result in
                result == .signIn
            }
        ))

        graph.addEdge(Edge(
            from: end,
            to: welcome,
            transition: .popTo(0),
            predicate: { _ in true }
        ))

        print("\(graph.prettyPrintOutline(from: "WelcomeNode"))")

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
        //let home = ScreenNode<Void, Void>("home")
        navController.start(at: WelcomeNode(), with: ())
    }
}
