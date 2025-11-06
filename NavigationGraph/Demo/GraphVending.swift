//
//  GraphVending.swift
//  NavigationGraph
//
//  Created by Michael Choe on 8/4/25.
//

protocol GraphVending {
    var registry: NodeRegistry { get }
    var graph: NavigationGraph { get }
}

/// Sign In Graph
///
/// START -> [SignIn Home] -> END
///                       \
///                        [Forgot Password] -> [Email Sent Alert] -|
///
struct SignInGraph: GraphVending {

    let registry: NodeRegistry

    var graph: NavigationGraph {
        let signinGraph = NavigationGraph()

        let signinHome = registry.resolve(SignInHomeNode.self)
        let forgotPassword = registry.resolve(ForgotPasswordNode.self)
        let oneShotErrorNode = registry.resolve(OneShotAlertNode.self)

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
                    return nil
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
        return signinGraph
    }
}


///
///                   [No item selected error] -|
///                  /
/// START -> [Gender] -> END
///                 \ \
///                  \ \
///                   \ [Beyond Binary] -> [Gender Re-entry] -> END
///                    \
///                     [Learn More] -|
///
struct GenderGraph: GraphVending {

    let registry: NodeRegistry
    
    var graph: NavigationGraph {
        let graph = NavigationGraph()

        graph.addNode(registry.resolve(GenderNode.self))
        graph.addNode(registry.resolve(BeyondBinaryNode.self))
        graph.addNode(registry.resolve(GenderLearnMoreNode.self))
        graph.addNode(registry.resolve(OneShotAlertNode.self))

        graph.addEdge(Edge(
            from: registry.resolve(GenderNode.self),
            to: registry.resolve(BeyondBinaryNode.self),
            transition: .push,
            predicate: { $0 == .beyondBinary }
        ))

        // Re-entry into the gender node
        graph.addEdge(Edge(
            from: registry.resolve(BeyondBinaryNode.self),
            to: registry.resolve(GenderNode.self),
            transition: .push,
            predicate: { _ in true },
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
            from: registry.resolve(GenderNode.self),
            to: registry.resolve(OneShotAlertNode.self),
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
            from: registry.resolve(OneShotAlertNode.self),
            to: registry.resolve(GenderNode.self),
            transition: .none,
            predicate: { _ in true },
            transform: { return nil }
        ))

        graph.addEdge(Edge(
            from: registry.resolve(GenderNode.self),
            to: registry.resolve(GenderLearnMoreNode.self),
            transition: .modal,
            predicate: { result in
                result == .learnMore
            }
        ))
        return graph
    }
}

/// Photo Selector Graph
///
/// START -> [Photos] -> END
///                  \
///                   [Photo Selector] -|
///
struct PhotoSelectorGraph: GraphVending {
    let registry: NodeRegistry

    var graph: NavigationGraph {
        let photoSelectorGraph = NavigationGraph()
        photoSelectorGraph.addNode(registry.resolve(PhotosNode.self))
        photoSelectorGraph.addNode(registry.resolve(PhotosSelectorNode.self))

        photoSelectorGraph.addEdge(Edge(
            from: registry.resolve(PhotosNode.self),
            to: registry.resolve(PhotosSelectorNode.self),
            transition: .modal,
            predicate: { result in
                return result == .photoSelector
            }
        ))

        photoSelectorGraph.addEdge(Edge(
            from: registry.resolve(PhotosSelectorNode.self),
            to: registry.resolve(PhotosNode.self),
            transition: .dismiss,
            predicate: { _ in true }
        ))
        return photoSelectorGraph
    }
}

// MARK: - Variant 1
struct DemoGraphVariant1: GraphVending {

    let registry: NodeRegistry

    var graph: NavigationGraph {

        let signinHome = registry.resolve(SignInHomeNode.self)
        let forgotPassword = registry.resolve(ForgotPasswordNode.self)
        let oneShotErrorNode = registry.resolve(OneShotAlertNode.self)
        let welcome = registry.resolve(WelcomeNode.self)
        let gender = registry.resolve(GenderNode.self)
        let beyondBinary = registry.resolve(BeyondBinaryNode.self)
        let safety = registry.resolve(SafetyNode.self)
        let genderLearnMore = registry.resolve(GenderLearnMoreNode.self)
        let photos = registry.resolve(PhotosNode.self)
        let photosSelector = registry.resolve(PhotosSelectorNode.self)
        let map = registry.resolve(MapNode.self)
        let end = registry.resolve(EndNode.self)

        let voidToVoidExit = registry.resolve(HeadlessNode<Void, Void>.self)

        let graph = NavigationGraph()

        graph.addNode(registry.resolve(WelcomeNode.self))
        graph.addNode(registry.resolve(OneShotAlertNode.self))

        let signInGraph = SignInGraph(registry: registry).graph
        let signInSubgraph = NavSubgraph(
            id: "signInSubgraph",
            graph: signInGraph,
            entry: signinHome,
            exit: voidToVoidExit
        )
        graph.addNode(signInSubgraph)

        graph.addEdge(Edge(
            from: welcome,
            to: signInSubgraph,
            transition: .push,
            predicate: { $0 == .signIn }
        ))

        graph.addNode(gender)
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

        graph.addNode(genderLearnMore)

        graph.addEdge(Edge(
            from: gender,
            to: genderLearnMore,
            transition: .modal,
            predicate: { result in
                result == .learnMore
            }
        ))

        // MARK: - Photo Selector Subgraph

        let photoSelectorGraph = NavigationGraph()
        photoSelectorGraph.addNode(photos)
        photoSelectorGraph.addNode(photosSelector)
        photoSelectorGraph.addNode(voidToVoidExit)

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

        photoSelectorGraph.addEdge(Edge(
            from: photos,
            to: voidToVoidExit,
            transition: .none,
            predicate: { _ in true }
        ))

        let photoSelectorSubgraph = NavSubgraph(
            id: "photoSelector",
            graph: photoSelectorGraph,
            entry: photos,
            exit: voidToVoidExit
        )

        // MARK: - Photo to Map Subgraph

        let photosToMapGraph = NavigationGraph()
        photosToMapGraph.addNode(map)
        photosToMapGraph.addNode(voidToVoidExit)
        photosToMapGraph.addSubgraph(photoSelectorSubgraph)

        photosToMapGraph.addEdge(Edge(
            from: photoSelectorSubgraph,
            to: map,
            transition: .push,
            predicate: { _ in
                true
            }
        ))

        photosToMapGraph.addEdge(Edge(
            from: map,
            to: voidToVoidExit,
            transition: .none,
            predicate: { _ in true }
        ))

        let photosToMapSubgraph = NavSubgraph(
            id: "photosToMap",
            graph: photosToMapGraph,
            entry: photoSelectorSubgraph,
            exit: voidToVoidExit
        )
        graph.addSubgraph(photosToMapSubgraph)

        graph.addEdge(Edge(
            from: gender,
            to: photosToMapSubgraph,
            transition: .push,
            predicate: { result in
                guard
                    case let GenderViewController.GenderResult.next(gender) = result,
                    gender == "Woman"
                else {
                    return false
                }
                return true
            }
        ))

        graph.addNode(safety)

        graph.addEdge(Edge(
            from: gender,
            to: safety,
            transition: .push,
            predicate: { result in
                guard
                    case let GenderViewController.GenderResult.next(gender) = result,
                    gender == "Beyond Binary"
                else {
                    return false
                }
                return true
            }
        ))

        graph.addEdge(Edge(
            from: safety,
            to: photosToMapSubgraph,
            transition: .push,
            predicate: { _ in true }
        ))

        // MARK: - Map to Photo Subgraph

        let mapToPhotosGraph = NavigationGraph()
        mapToPhotosGraph.addNode(map)
        mapToPhotosGraph.addNode(voidToVoidExit)
        mapToPhotosGraph.addSubgraph(photoSelectorSubgraph)

        mapToPhotosGraph.addEdge(Edge(
            from: map,
            to: photoSelectorSubgraph,
            transition: .push,
            predicate: { _ in
                true
            }
        ))

        mapToPhotosGraph.addEdge(Edge(
            from: photoSelectorSubgraph,
            to: voidToVoidExit,
            transition: .none,
            predicate: { _ in true }
        ))

        let mapToPhotosSubgraph = NavSubgraph(
            id: "mapToPhotos",
            graph: mapToPhotosGraph,
            entry: map,
            exit: voidToVoidExit
        )
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
            predicate: { _ in true }
        ))

        graph.addEdge(Edge(
            from: end,
            to: welcome,
            transition: .popTo(0),
            predicate: { _ in true }
        ))

        print("\(graph.prettyPrintOutline(from: "WelcomeNode"))")

        return graph
    }
}

/*
struct DemoGraphVariant2: GraphVending {

    let registry: NodeRegistry

    var graph: NavigationGraph {

        let signinHome = registry.resolve(SignInHomeNode.self)
        let oneShotErrorNode = registry.resolve(OneShotAlertNode.self)
        let welcome = registry.resolve(WelcomeNode.self)
        let gender = registry.resolve(GenderNode.self)
        let beyondBinary = registry.resolve(BeyondBinaryNode.self)
        let genderLearnMore = registry.resolve(GenderLearnMoreNode.self)
        let photos = registry.resolve(PhotosNode.self)
        let photosSelector = registry.resolve(PhotosSelectorNode.self)
        let map = registry.resolve(MapNode.self)
        let end = registry.resolve(EndNode.self)

        let graph = NavigationGraph()

        graph.addNode(registry.resolve(WelcomeNode.self))
        graph.addNode(registry.resolve(OneShotAlertNode.self))

        // Sign In Subgraph
        let signInGraph = SignInGraph(registry: registry)
        let signInSubgraph = NavSubgraph(id: "signInSubgraph", graph: signInGraph.graph, start: signinHome)
        graph.addSubgraph(signInSubgraph)

        graph.addEdge(Edge(
            from: welcome,
            to: signInSubgraph,
            transition: .push,
            predicate: { $0 == .signIn }
        ))

        graph.addNode(gender)
        graph.addNode(beyondBinary)

        /*
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
         */

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

        graph.addNode(genderLearnMore)

        graph.addEdge(Edge(
            from: gender,
            to: genderLearnMore,
            transition: .modal,
            predicate: { result in
                result == .learnMore
            }
        ))

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

        /*
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
         */

        graph.addNode(photoSelectorSubgraph)
        graph.addNode(map)
        graph.addNode(end)

        graph.addEdge(Edge(
            from: welcome,
            to: photoSelectorSubgraph,
            transition: .push,
            predicate: { _ in true }
        ))

        graph.addEdge(Edge(
            from: photoSelectorSubgraph,
            to: gender,
            transition: .push,
            predicate: { _ in true },
            transform: { _ in nil }
        ))

        graph.addEdge(Edge(
            from: gender,
            to: map,
            transition: .push,
            predicate: { _ in true }
        ))

        graph.addEdge(Edge(
            from: map,
            to: end,
            transition: .push,
            predicate: { _ in true }
        ))

        /*
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
         */

        //graph.addNode(end)

        /*
        graph.addEdge(Edge(
            from: mapToPhotosSubgraph,
            to: end,
            transition: .push,
            predicate: { _ in true }
        ))
         */

        /*
        graph.addEdge(Edge(
            from: photosToMapSubgraph,
            to: end,
            transition: .push,
            predicate: { _ in true }
        ))
         */

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

        return graph
    }
}
*/

// MARK: - Variant 2

/// Main Graph
///
/// START -> [Welcome] -> |[Gender Subgraph]|
///                   \
///                    |[SignIn Subgraph]|

/*
struct DemoGraphVariant2: GraphVending {

    var registry: NodeRegistry

    var graph: NavigationGraph {
        let graph = NavigationGraph()

        graph.addNode(registry.resolve(WelcomeNode.self))
        graph.addNode(registry.resolve(OneShotAlertNode.self))
        graph.addNode(registry.resolve(GenderNode.self))
        graph.addNode(registry.resolve(PhotosNode.self))

        // Sign In Subgraph
        let signInGraph = SignInGraph(registry: registry)
        let signInSubgraph = NavSubgraph(
            id: "signInSubgraph",
            graph: signInGraph.graph,
            start: registry.resolve(SignInHomeNode.self)
        )
        graph.addSubgraph(signInSubgraph)

        graph.addEdge(Edge(
            from: registry.resolve(WelcomeNode.self),
            to: signInSubgraph,
            transition: .push,
            predicate: { $0 == .signIn }
        ))

        let genderGraph = GenderGraph(registry: registry)
        let genderSubgraph = NavSubgraph(
            id: "genderSubgraph",
            graph: genderGraph.graph,
            start: registry.resolve(GenderNode.self)
        )
        graph.addSubgraph(genderSubgraph)
        graph.addEdge(Edge(
            from: registry.resolve(WelcomeNode.self),
            to: genderSubgraph,
            transition: .push,
            predicate: { $0 == .next },
            transform: { _ in nil }
        ))

        // MARK: - Photo Selector Subgraph

        let photoSelectorGraph = PhotoSelectorGraph(registry: registry)
        let photoSelectorSubgraph = NavSubgraph(
            id: "photoSelectorSubgraph",
            graph: photoSelectorGraph.graph,
            start: registry.resolve(PhotosNode.self)
        )
        graph.addNode(photoSelectorSubgraph)

        // MARK: - Photo to Map Subgraph

        let photosToMapGraph = NavigationGraph()
        photosToMapGraph.addNode(registry.resolve(MapNode.self))
        photosToMapGraph.addSubgraph(photoSelectorSubgraph)

        photosToMapGraph.addEdge(Edge(
            from: photoSelectorSubgraph,
            to: registry.resolve(MapNode.self),
            transition: .push,
            predicate: { _ in
                true
            }
        ))

        let photosToMapSubgraph = NavSubgraph(id: "photosToMap", graph: photosToMapGraph, start: photoSelectorSubgraph)
        graph.addSubgraph(photosToMapSubgraph)

        graph.addEdge(Edge(
            from: registry.resolve(GenderNode.self),
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
        mapToPhotosGraph.addNode(registry.resolve(MapNode.self))
        mapToPhotosGraph.addSubgraph(photoSelectorSubgraph)

        mapToPhotosGraph.addEdge(Edge(
            from: registry.resolve(MapNode.self),
            to: photoSelectorSubgraph,
            transition: .push,
            predicate: { _ in
                true
            }
        ))

        let mapToPhotosSubgraph = NavSubgraph(id: "mapToPhotos", graph: mapToPhotosGraph, start: registry.resolve(MapNode.self))
        graph.addSubgraph(mapToPhotosSubgraph)

        graph.addEdge(Edge(
            from: registry.resolve(GenderNode.self),
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


        graph.addNode(registry.resolve(EndNode.self))

        graph.addEdge(Edge(
            from: mapToPhotosSubgraph,
            to: registry.resolve(EndNode.self),
            transition: .push,
            predicate: { _ in true }
        ))

        graph.addEdge(Edge(
            from: photosToMapSubgraph,
            to: registry.resolve(EndNode.self),
            transition: .push,
            predicate: { _ in true }
        ))

        graph.addEdge(Edge(
            from: signInSubgraph,
            to: registry.resolve(EndNode.self),
            transition: .push,
            predicate: { result in
                result == .signIn
            }
        ))

        graph.addEdge(Edge(
            from: registry.resolve(EndNode.self),
            to: registry.resolve(WelcomeNode.self),
            transition: .popTo(0),
            predicate: { _ in true }
        ))

        print("\(graph.prettyPrintOutline(from: "WelcomeNode"))")

        return graph
    }
}

extension GraphVending {

}
*/
