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
        /// The subgraph node that this item belongs to, if any.
        /// This allows us to identify which nodes are part of which subgraph
        /// and recursively check parent subgraphs for outgoing edges.
        let parentSubgraphNode: AnyNavNode?
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
            -------------
            [NAV]: Stack now contains \(nodeStack.count) items:
            \(nodeStack.map(\.node.id).joined(separator: " -> "))
            """)
        }
    }
    
    /// A stack tracking which subgraphs we're currently nested in.
    /// When entering a subgraph, we push the subgraph node onto this stack.
    /// When exiting (no edges found), we can look at this stack to find
    /// the correct parent context for edge resolution.
    private var subgraphStack: [AnyNavNode] = [] {
        didSet {
            print("""
            [NAV]: Subgraph stack now contains \(subgraphStack.count) items:
            \(subgraphStack.map(\.id).joined(separator: " -> "))
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
        show(node: wrapped, data: data, incomingTransition: .push, graph: graph, parentSubgraphNode: nil)
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
        graph currentGraph: NavigationGraph,
        parentSubgraphNode: AnyNavNode? = nil
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
            
            // Push this subgraph onto the subgraph stack
            subgraphStack.append(node)
            print("[NAV DEBUG]: Pushed subgraph \(node.id) onto stack. Stack now: \(subgraphStack.map(\.id))")
            
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
            // Pass the current subgraph node as the parent for nodes within this subgraph
            print("[NAV DEBUG]: Entering subgraph \(node.id), setting parentSubgraphNode to \(node.id) for start node \(startWrapped.id)")
            show(node: startWrapped, data: data, incomingTransition: incomingTransition, graph: wrapper.graph, parentSubgraphNode: node)
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
                incomingTransition: incomingTransition,
                parentSubgraphNode: parentSubgraphNode
            ))
        case .none:
            nodeStack.removeLast()
        case .pop:
            // Should pop back to ancestor
            navigationController.popViewController(animated: true)
            nodeStack.removeLast()
        case .popTo(let index):

            if index == 0 {
                navigationController.popToRootViewController(animated: true)
                nodeStack.removeLast(navigationController.viewControllers.count - 1)
                //subgraphStack.removeAll()
                return
            }

            let dropTotal = navigationController.viewControllers.count - index - 1

            _ = navigationController.viewControllers.dropLast(dropTotal)
        case .push:
            navigationController.pushViewController(viewController, animated: true)
            
            print("[NAV DEBUG]: Adding node \(node.id) to stack with parentSubgraphNode: \(parentSubgraphNode?.id ?? "nil")")
            nodeStack.append(StackItem(
                node: node,
                data: data,
                graph: currentGraph,
                incomingTransition: incomingTransition,
                parentSubgraphNode: parentSubgraphNode
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
            // No eligible edges in current graph; try to exit subgraphs recursively
            if tryExitSubgraph(for: node, with: output, from: view) {
                return
            }
            // No eligible edges found at any level; remain on the current screen
            print("""
            -----------------------------------
            [NAV]: No eligible edges found for \(node.fullyQualifiedId), staying on current screen
            """)
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
                show(node: dest, data: nextData, incomingTransition: chosen.transition, graph: currentGraph, parentSubgraphNode: currentEntry.parentSubgraphNode)
            }
        } else {
            show(node: dest, data: nextData, incomingTransition: chosen.transition, graph: currentGraph, parentSubgraphNode: currentEntry.parentSubgraphNode)
        }

    }
    
    /// Attempts to exit the current subgraph and find an edge in a parent subgraph.
    /// Uses the subgraph stack to recursively check parent contexts until an edge is found.
    /// Returns true if navigation occurred, false if no valid exit was found.
    private func tryExitSubgraph(for node: AnyNavNode, with output: Any, from view: UIViewController) -> Bool {
        guard !subgraphStack.isEmpty else {
            print("[NAV DEBUG]: No subgraphs in stack, cannot exit")
            return false
        }
        
        print("[NAV DEBUG]: Trying to exit subgraph. Current node: \(node.id)")
        print("[NAV DEBUG]: Subgraph stack: \(subgraphStack.map(\.id).joined(separator: " -> "))")
        
        // Try each subgraph in the stack, starting from the most recent (innermost)
        for i in (0..<subgraphStack.count).reversed() {
            let subgraphToExit = subgraphStack[i]
            let parentGraph = findParentGraphForSubgraph(at: i)
            
            print("[NAV DEBUG]: Checking if we can exit subgraph \(subgraphToExit.id) into parent graph")
            print("[NAV DEBUG]: Current node output type: \(type(of: output)), value: \(output)")
            print("[NAV DEBUG]: Subgraph to exit: \(subgraphToExit.id)")
            
            // Check what edges exist for this subgraph
            let subgraphEdges = parentGraph.adjacency[subgraphToExit.id] ?? []
            print("[NAV DEBUG]: Subgraph \(subgraphToExit.id) has \(subgraphEdges.count) outgoing edges in parent graph")
            
            // IMPORTANT: When exiting a subgraph, we have a type mismatch issue:
            // The subgraph's OutputType is based on its start node, but we're exiting from
            // a different node with a different output type. We'll pass the original output
            // and handle the type mismatch in the Edge's predicateAny wrapper.
            let subgraphOutput: Any = output
            print("[NAV DEBUG]: Using original output (\(type(of: output))) for subgraph edge predicate evaluation")
            
            if let edge = findEligibleEdge(for: subgraphToExit, with: subgraphOutput, in: parentGraph) {
                print("""
                -----------------------------------
                [NAV]: Found exit! Exiting subgraph \(subgraphToExit.id) 
                \(subgraphToExit.id) --|\(edge.transition)|--> \(edge.toNode.id)
                """)
                
                // Remove all subgraphs from this level and deeper
                subgraphStack.removeSubrange(i...)
                print("[NAV DEBUG]: Cleaned subgraph stack, now contains: \(subgraphStack.map(\.id))")
                
                // Navigate to the destination
                show(
                    node: edge.toNode, 
                    data: edge.applyTransform(output), 
                    incomingTransition: edge.transition, 
                    graph: parentGraph,
                    parentSubgraphNode: subgraphStack.last
                )
                return true
            }
        }
        
        print("[NAV DEBUG]: No exit found at any level")
        return false
    }
    
    /// Try to exit at a specific subgraph level
    private func tryExitAtLevel(parentSubgraphNode: AnyNavNode, output: Any, from view: UIViewController) -> Bool {
        print("[NAV DEBUG]: Trying to find edges from \(parentSubgraphNode.id)")
        
        // Collect all possible graphs to check
        var graphsToCheck: [(NavigationGraph, String)] = []
        
        // Add main graph
        graphsToCheck.append((self.graph, "main graph"))
        
        // Add all subgraph internal graphs we can find by looking at any subgraph wrappers
        // We need to check every possible subgraph's internal graph
        for stackItem in nodeStack {
            if let wrapper = stackItem.node.subgraphWrapper {
                graphsToCheck.append((wrapper.graph, "subgraph \(stackItem.node.id)"))
            }
        }
        
        // Also check the immediate current graph context in case we missed it
        if let currentEntry = nodeStack.last {
            let currentGraph = currentEntry.graph
            if !graphsToCheck.contains(where: { $0.0 === currentGraph }) {
                graphsToCheck.append((currentGraph, "current graph"))
            }
        }
        
        print("[NAV DEBUG]: Checking \(graphsToCheck.count) possible graphs")
        
        // Try each graph until we find one with edges from our parent subgraph
        for (graph, description) in graphsToCheck {
            print("[NAV DEBUG]: Checking \(description) for edges from \(parentSubgraphNode.id)")
            
            if let chosen = findEligibleEdge(for: parentSubgraphNode, with: output, in: graph) {
                print("""
                -----------------------------------
                [NAV]: Found exit in \(description)! 
                \(parentSubgraphNode.fullyQualifiedId) --|\(chosen.transition)|--> \(chosen.toNode.fullyQualifiedId)
                """)
                
                navigateUsingEdge(chosen, with: output, from: view, in: graph, exitingSubgraph: parentSubgraphNode)
                return true
            }
        }
        
        print("[NAV DEBUG]: No exit found in any graph for subgraph \(parentSubgraphNode.id)")
        return false
    }
    
    /// Finds the correct parent graph for a subgraph at the given index in the subgraph stack.
    /// - Parameter index: The index in the subgraph stack (0 = outermost, count-1 = innermost)
    /// - Returns: The graph that contains edges from the subgraph at this level
    private func findParentGraphForSubgraph(at index: Int) -> NavigationGraph {
        print("[NAV DEBUG]: Finding parent graph for subgraph at index \(index)")
        if index == 0 {
            // The outermost subgraph's parent is always the main graph
            print("[NAV DEBUG]: Returning main graph for outermost subgraph")
            return self.graph
        } else {
            // For nested subgraphs, the parent is the internal graph of the subgraph one level up
            let parentSubgraph = subgraphStack[index - 1]
            print("[NAV DEBUG]: Parent subgraph is \(parentSubgraph.id)")
            guard let parentWrapper = parentSubgraph.subgraphWrapper else {
                fatalError("Subgraph \(parentSubgraph.id) has no wrapper")
            }
            print("[NAV DEBUG]: Returning internal graph of \(parentSubgraph.id)")
            return parentWrapper.graph
        }
    }
    
    /// Recursively attempts to exit further up the subgraph hierarchy
    private func tryExitSubgraphRecursively(for subgraphNode: AnyNavNode, with output: Any, from view: UIViewController) -> Bool {
        // Find which stack item contains this subgraph node to get its parent subgraph
        guard let subgraphStackItem = nodeStack.first(where: { $0.node.id == subgraphNode.id }),
              let parentSubgraphNode = subgraphStackItem.parentSubgraphNode else {
            return false
        }
        
        // Find the parent graph for this level
        guard let parentGraph = findParentGraph(for: parentSubgraphNode) else {
            return false
        }
        
        // Check for edges from the parent subgraph
        if let chosen = findEligibleEdge(for: parentSubgraphNode, with: output, in: parentGraph) {
            print("""
            -----------------------------------
            [NAV]: Exiting nested subgraph \(parentSubgraphNode.id)
            \(parentSubgraphNode.fullyQualifiedId) --|\(chosen.transition)|--> \(chosen.toNode.fullyQualifiedId)
            Input data: \(output)
            """)
            
            navigateUsingEdge(chosen, with: output, from: view, in: parentGraph, exitingSubgraph: parentSubgraphNode)
            return true
        }
        
        // Continue recursively up the hierarchy
        return tryExitSubgraphRecursively(for: parentSubgraphNode, with: output, from: view)
    }
    
    /// Finds an eligible edge for a node with given output in the specified graph
    private func findEligibleEdge(for node: AnyNavNode, with output: Any, in graph: NavigationGraph) -> AnyNavEdge? {
        let edges = graph.adjacency[node.id] ?? []
        print("[NAV DEBUG]: Checking \(edges.count) edges for node \(node.id)")
        print("[NAV DEBUG]: Output data type: \(type(of: output)), value: \(output)")
        print("[NAV DEBUG]: Node ID being searched: '\(node.id)'")
        
        // First, let's see what keys are actually in the adjacency list
        print("[NAV DEBUG]: Available nodes in adjacency list: \(Array(graph.adjacency.keys).sorted())")
        
        let candidates = edges.filter { edge in
            print("[NAV DEBUG]: Evaluating edge \(node.id) -> \(edge.toNode.id)")
            print("[NAV DEBUG]: Edge ID: \(edge.id)")
            
            // Let's try to see what happens in the predicate
            print("[NAV DEBUG]: About to call predicateAny with \(type(of: output))")
            let result = edge.predicateAny(output)
            print("[NAV DEBUG]: Edge \(node.id) -> \(edge.toNode.id): predicate result = \(result)")
            
            if !result {
                print("[NAV DEBUG]: Predicate failed! This suggests a type mismatch or other issue")
                print("[NAV DEBUG]: Testing predicate with different types to understand what it expects...")
                
                // Test with void
                print("[NAV DEBUG]: Testing predicate with () (void)...")
                let voidResult = edge.predicateAny(())
                print("[NAV DEBUG]: Predicate with void: \(voidResult)")
                
                // Test with String
                print("[NAV DEBUG]: Testing predicate with String...")
                let stringResult = edge.predicateAny("test")
                print("[NAV DEBUG]: Predicate with string: \(stringResult)")
                
                // Test with Int
                print("[NAV DEBUG]: Testing predicate with Int...")
                let intResult = edge.predicateAny(42)
                print("[NAV DEBUG]: Predicate with int: \(intResult)")
                
                // Test with a dummy struct
                struct DummyOutput {}
                let dummyResult = edge.predicateAny(DummyOutput())
                print("[NAV DEBUG]: Predicate with DummyOutput: \(dummyResult)")
                
                // Let's also inspect the edge to see if we can understand what it expects
                print("[NAV DEBUG]: Edge fromNode type: \(type(of: edge.fromNode))")
                print("[NAV DEBUG]: Edge fromNode id: \(edge.fromNode.id)")
            }
            
            return result
        }
        
        print("[NAV DEBUG]: Found \(candidates.count) eligible edges for node \(node.id)")
        return candidates.first
    }
    
    /// Finds the parent graph that contains the given subgraph node
    private func findParentGraph(for subgraphNode: AnyNavNode) -> NavigationGraph? {
        // Look through the stack to find where this subgraph was added
        for (index, stackItem) in nodeStack.enumerated() {
            if stackItem.node.id == subgraphNode.id {
                // The parent graph is the graph from the previous stack level,
                // or the main graph if this is at the top level
                if index > 0 {
                    return nodeStack[index - 1].graph
                } else {
                    return graph // Return the main graph
                }
            }
        }
        
        // If not found in stack, this subgraph must be at the top level
        return graph
    }
    
    /// Navigates using the chosen edge, cleaning up subgraph stack items as needed
    private func navigateUsingEdge(_ edge: AnyNavEdge, with output: Any, from view: UIViewController, in graph: NavigationGraph, exitingSubgraph: AnyNavNode) {
        let nextData = edge.applyTransform(output)
        
        // Clean up the stack: remove all items that belong to the exiting subgraph
        cleanupStackForSubgraphExit(exitingSubgraph: exitingSubgraph)
        
        guard let dest = graph.nodes[edge.toNode.id] else {
            fatalError("Destination node \(edge.toNode.id) is not registered in the graph")
        }
        
        // Determine the parent subgraph context for the new destination
        let newParentSubgraph = findParentSubgraphForDestination(in: graph)
        
        // Handle modal dismissal before showing next node
        if let currentEntry = nodeStack.last, currentEntry.incomingTransition == .modal {
            view.dismiss(animated: true) { [weak self] in
                guard let self else { return }
                self.show(node: dest, data: nextData, incomingTransition: edge.transition, graph: graph, parentSubgraphNode: newParentSubgraph)
            }
        } else {
            show(node: dest, data: nextData, incomingTransition: edge.transition, graph: graph, parentSubgraphNode: newParentSubgraph)
        }
    }
    
    /// Cleans up stack items that belong to the exiting subgraph
    private func cleanupStackForSubgraphExit(exitingSubgraph: AnyNavNode) {
        // Remove all items from the stack that belong to the exiting subgraph
        while let lastItem = nodeStack.last, 
              lastItem.parentSubgraphNode?.id == exitingSubgraph.id || lastItem.node.id == exitingSubgraph.id {
            nodeStack.removeLast()
        }
    }
    
    /// Determines the parent subgraph context for a destination node in the given graph
    private func findParentSubgraphForDestination(in graph: NavigationGraph) -> AnyNavNode? {
        // If we're navigating within the main graph, no parent subgraph
        if graph === self.graph {
            return nil
        }
        
        // Find which subgraph contains this graph
        for stackItem in nodeStack.reversed() {
            if let subgraphWrapper = stackItem.node.subgraphWrapper,
               subgraphWrapper.graph === graph {
                return stackItem.node
            }
        }
        
        return nil
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
