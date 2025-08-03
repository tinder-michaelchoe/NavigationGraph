//
//  NavigationController.swift
//  NavigationGraph
//
//  Created by mexicanpizza on 7/29/25.
//

import UIKit

/// A `NavigationController` coordinates navigation through a
/// `NavigationGraph` using an event‑driven approach.  Instead of
/// awaiting each screen asynchronously, the controller presents
/// view controllers, listens for completion callbacks and responds
/// to back/presentation events to maintain its own stack of nodes.
/// This design allows users to freely navigate forward and backward
/// (using the navigation bar's back button or swipe gestures)
/// without crashing due to pending continuations.  It also
/// supports nested subgraphs by switching between graphs based on
/// the current node.
public final class NavigationController: NSObject {
    
    private struct StackItem {
        let node: AnyNavNode
        let data: Any
        let graph: NavigationGraph
        let incomingTransition: TransitionType
    }
    
    /// The top‑level navigation graph describing the flow.
    private let graph: NavigationGraph
    
    /// The UIKit navigation controller used to present view controllers.
    private let navigationController: UINavigationController
    
    /// A factory closure that produces a view controller for a given
    /// node and input data.  The returned controller must conform to
    /// `NavigableViewController` so that the navigation controller can
    /// be notified when the user has finished interacting with it.
    //private let viewControllerFactory: (AnyNavNode, Any) -> (UIViewController & NavigableViewController)
    
    /// A stack of visited nodes along with their input data, the
    /// graph used to resolve outgoing edges for that node and the
    /// transition used to present that node.  The last element
    /// represents the current screen.  When a view controller is
    /// popped, the corresponding entry is removed from this stack.
    private var nodeStack: [StackItem] = [] {
        didSet {
            print("""
            Node Stack: \(nodeStack.map({ $0.node.fullyQualifiedId }))
            """)
        }
    }

    /// A mapping from view controllers to the nodes they represent.
    //private var viewControllerToNode: [UIViewController: AnyNavNode] = [:]
    private var anyViewControllerToNode: [Int: AnyNavNode] = [:]
    
    private var allNodes: [String : AnyNavNode] = [:]

    /// Creates a new navigation controller for the given graph and presenter.
    public init(
        graph: NavigationGraph,
        navigationController: UINavigationController
    ) {
        self.graph = graph
        self.navigationController = navigationController
        super.init()

        self.navigationController.delegate = self
    }

    /// Starts navigating from the specified node using the provided
    /// initial data.  This method clears any previous state and
    /// presents the first view controller.  The initial node must be
    /// present within the controller's graph; otherwise, this method
    /// crashes.
    public func start<Start: NavNode>(at start: Start, with data: Start.InputType) {
        guard let wrapped = graph.nodes[start.id] else {
            fatalError("Starting node \(start.id) is not registered in the graph")
        }

        print("""
        ----------------------------
        [NAV]: Starting at node \(start.id)
        """)
        show(node: wrapped, data: data, incomingTransition: .push, graph: graph)
    }

    /// Presents a node on screen using the provided data, transition
    /// and graph.  This method pushes the node onto the internal
    /// stack, creates a view controller via the factory, sets up its
    /// completion callback and presents it using the appropriate
    /// transition.  If the node represents a nested subgraph, this
    /// method instead pushes the subgraph onto the stack and then
    /// immediately begins navigating within the subgraph starting at
    /// its designated start node.
    private func show(
        node: AnyNavNode,
        data: Any,
        incomingTransition: TransitionType,
        graph currentGraph: NavigationGraph
    ) {
        
        // If the node represents a nested subgraph, push it onto the
        // stack using the currentGraph (the parent graph), then
        // immediately navigate to the start node of the subgraph using
        // the subgraph's internal graph.
        if let wrapper = node.subgraphWrapper {
            // Log entering a subgraph.
            print("""
            ----------------------------
            [NAV]: entering subgraph \(wrapper.id) starting at \(wrapper.startNodeId)
            """)
            // Push the subgraph placeholder onto the stack.  Edges
            // leaving this placeholder live in the parent graph, so
            // record the parent graph as the graph to use for this
            // entry, along with the incoming transition.
            /*
            nodeStack.append(StackItem(
                node: node,
                data: data,
                graph: currentGraph,
                incomingTransition: incomingTransition
            ))
             */
            // Determine the start node of the subgraph.
            guard let startWrapped = wrapper.graph.nodes[wrapper.startNodeId] else {
                fatalError("Start node \(wrapper.startNodeId) is not registered in subgraph \(wrapper.id)")
            }
            // Begin the subgraph flow.  Use the subgraph's internal
            // graph when resolving edges for nodes inside the subgraph.
            show(node: startWrapped, data: data, incomingTransition: incomingTransition, graph: wrapper.graph)
            return
        }
        
        // UIViewController case, need to add SwiftUI View case
        guard
            let anyViewControllerProviding = node.anyViewControllerProviding,
            let viewController = anyViewControllerProviding.viewControllerFactory(data).wrapped as? (any NavigableViewController)
        else {
            fatalError("Couldn't find view controller provider.")
        }
        
        let anyNavigableViewController = AnyNavigableViewController(viewController)
        
        anyViewControllerToNode[anyNavigableViewController.hash] = node
        anyNavigableViewController.onComplete = { [weak self, weak viewController] output in
            guard let self, let viewController else { return }
            handleCompletion(from: viewController, output: output)
        }

        switch incomingTransition {
        case .dismiss:
            navigationController.dismiss(animated: true)
            nodeStack.removeLast()
        case .modal:
            // iOS doesn't allow setting the delegate for alerts
            if !(viewController is UIAlertController) {
                viewController.presentationController?.delegate = self
            }
            navigationController.present(viewController, animated: true)

            nodeStack.append(StackItem(
                node: node,
                data: data,
                graph: currentGraph,
                incomingTransition: incomingTransition
            ))
        case .none:
            break
        case .pop:
            // Should pop back to ancestor
            navigationController.popViewController(animated: true)
            nodeStack.removeLast()
        case .push:
            navigationController.pushViewController(viewController, animated: true)
            
            nodeStack.append(StackItem(
                node: node,
                data: data,
                graph: currentGraph,
                incomingTransition: incomingTransition
            ))
        }
    }

    /// Handles completion of a view controller.  It looks up the
    /// corresponding node, determines the next edge to follow (if any)
    /// and presents the next node.  If there are no outgoing edges,
    /// this method simply returns, leaving the user on the current
    /// screen.
    private func handleCompletion(from view: UIViewController, output: Any) {
        guard
            let navigableViewController = view as? any NavigableViewController,
            let node = anyViewControllerToNode[AnyNavigableViewController(navigableViewController).hash],
            let currentEntry = nodeStack.last
        else {
            fatalError("Couldn't get last node.")
        }
        let currentGraph = currentEntry.graph
        let incoming = currentEntry.incomingTransition
        // Look up outgoing edges for the node in the appropriate graph.
        let edges = currentGraph.adjacency[node.id] ?? []
        // Filter edges based on their predicate.  The predicate is
        // evaluated against the data returned from the screen.  Only
        // edges whose predicate returns `true` are considered.
        let candidates = edges.filter { edge in
            return edge.predicateAny(output)
        }
        guard !candidates.isEmpty else {
            // No eligible edges; remain on the current screen.
            return
        }
        // Choose the first eligible edge.  If multiple edges are
        // eligible, they should be ordered according to desired
        // precedence when registering them.
        let chosen = candidates[0]
        // Compute the data for the next node using the edge's transform.
        let nextData = chosen.applyTransform(output)
        // Log the chosen navigation step.  Include current node, destination,
        // transition type and a description of the data transformation.
        //let currentId = node.id
        //let nextId = chosen.toNode.id
        let transitionType = chosen.transition
        print("""
        -----------------------------------
        \(node.fullyQualifiedId) --|\(transitionType)|--> \(chosen.toNode.fullyQualifiedId)
        Input data: \(output)
        Transformed data: \(nextData)
        """)
        // Determine the destination node within the current graph.
        guard let dest = currentGraph.nodes[chosen.toNode.id] else {
            fatalError("Destination node \(chosen.toNode.id) is not registered in the current graph")
        }
        // If this screen was presented modally, dismiss it before
        // presenting the next screen.  UIKit cannot present a new
        // controller while another is being presented.  Otherwise,
        // simply show the next node immediately.
        if incoming == .modal {
            // Dismiss the current view controller.  Once dismissal
            // completes, present the next node.  Capture self weakly
            // to avoid retain cycles.
            view.dismiss(animated: true) { [weak self] in
                guard let self else { return }
                show(node: dest, data: nextData, incomingTransition: chosen.transition, graph: currentGraph)
            }
        } else {
            show(node: dest, data: nextData, incomingTransition: chosen.transition, graph: currentGraph)
        }

    }

    /// Handles the case where a view controller has been popped or
    /// dismissed.  It removes the corresponding node from the
    /// internal stack and cleans up the mapping.  This method is
    /// called from the navigation controller delegate and the
    /// presentation controller delegate.
    private func handlePop(for view: UIViewController) {
        guard
            let navigableViewController = view as? any NavigableViewController,
            let poppedNode = anyViewControllerToNode[AnyNavigableViewController(navigableViewController).hash]
        else { return }
        anyViewControllerToNode[AnyNavigableViewController(navigableViewController).hash] = nil
        
        nodeStack.removeLast()
        // Log the pop.  Report the popped node and the new top of the stack if any.
        let newTop = nodeStack.last?.node.id ?? "none"
        print("""
        ------------------------------------
        [NAV]: popped node \(poppedNode.id). Current node is now \(newTop)
        """)

    }
}

// MARK: - UINavigationControllerDelegate

// Removed duplicate UINavigationControllerDelegate extension
extension NavigationController: UINavigationControllerDelegate {
    public func navigationController(
        _ navController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        // Determine if a view controller was popped by comparing the
        // transition coordinator's fromVC.  If the fromVC is no longer
        // present in the stack, a pop occurred.
        guard let fromVC = navController.transitionCoordinator?.viewController(forKey: .from),
            !navController.viewControllers.contains(fromVC)
        else {
            return
        }
        handlePop(for: fromVC)
    }
}

// MARK: - UIAdaptivePresentationControllerDelegate

// Removed duplicate UIAdaptivePresentationControllerDelegate extension
extension NavigationController: UIAdaptivePresentationControllerDelegate {
    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        // When a modal is dismissed interactively (e.g. by swiping
        // down), treat it as a pop and update the stack.
        let dismissedVC = presentationController.presentedViewController
        handlePop(for: dismissedVC)
    }
}
