//
//  NavigationController.swift
//  NavigationGraph
//
//  Created by mexicanpizza on 7/29/25.
//

import UIKit

/// A controller that manages navigation through a `NavigationGraph` using an event-driven approach.
///
/// `NavigationController` coordinates navigation between screens by presenting view controllers,
/// listening for completion callbacks, and responding to user navigation actions like back button
/// taps or swipe gestures. This design allows for natural user interaction without blocking
/// navigation flows.
///
/// ## Overview
///
/// Unlike traditional async-await navigation patterns, `NavigationController` uses an event-driven
/// architecture that:
/// - Maintains its own stack of visited nodes
/// - Supports subgraph navigation with automatic context switching
/// - Handles both forward and backward navigation seamlessly
/// - Provides comprehensive logging for debugging navigation flows
///
/// ## Key Features
///
/// - **Non-blocking navigation**: Users can navigate back freely without crashing pending operations
/// - **Subgraph support**: Automatic handling of nested navigation flows
/// - **Multiple transition types**: Push, modal, pop, and custom transitions
/// - **Debug logging**: Detailed console output for tracking navigation state
/// - **UIKit integration**: Works seamlessly with `UINavigationController`
///
/// ## Example Usage
///
/// ```swift
/// let navController = NavigationController(
///     graph: navigationGraph,
///     navigationController: UINavigationController()
/// )
///
/// // Start navigation at the welcome screen
/// navController.start(at: WelcomeNode(), with: ())
/// ```
///
/// ## Navigation Flow
///
/// 1. **Start**: Begin navigation at a specific node with initial data
/// 2. **Present**: Show view controller for current node
/// 3. **Complete**: View controller calls completion handler with output data
/// 4. **Evaluate**: Find eligible edges based on output and predicates
/// 5. **Navigate**: Move to next node or exit subgraph if no edges found
///
/// ## Thread Safety
///
/// NavigationController should only be used on the main queue. All navigation operations
/// involve UIKit components that require main thread access.
public final class NavigationController: NSObject {

    /// Internal representation of a node in the navigation stack.
    ///
    /// Each stack item captures the complete context needed to understand
    /// the current navigation state and handle transitions.
    private struct StackItem {
        /// The navigation node being presented.
        let node: AnyNavNode
        
        /// The input data provided to this node.
        let data: Any
        
        /// The graph context used for resolving edges from this node.
        let graph: NavigationGraph
        
        /// The transition type used to present this node.
        let incomingTransition: TransitionType
    }
    
    /// The top-level navigation graph describing the application flow.
    private let graph: NavigationGraph
    
    /// The UIKit navigation controller used to present view controllers.
    private let navigationController: UINavigationController
    
    /// A stack of visited nodes with their associated context.
    ///
    /// The last element represents the current screen. When a view controller
    /// is popped, the corresponding entry is removed from this stack.
    ///
    /// ## Debug Output
    ///
    /// Changes to this stack automatically trigger console logging showing
    /// the current navigation path.
    private var nodeStack: [StackItem] = [] {
        didSet {
            print("""
            -------------
            [NAV]: Stack now contains \(nodeStack.count) items:
            \(nodeStack.map(\.node.id).joined(separator: " -> "))
            """)
        }
    }
    
    /// A stack tracking nested subgraph contexts.
    ///
    /// When entering a subgraph, the subgraph node is pushed onto this stack.
    /// When exiting (no eligible edges found), this stack helps determine
    /// the correct parent context for continued navigation.
    ///
    /// ## Debug Output
    ///
    /// Changes to this stack automatically trigger console logging showing
    /// the current subgraph nesting.
    private var subgraphStack: [AnyNavNode] = [] {
        didSet {
            print("""
            [NAV]: Subgraph stack now contains \(subgraphStack.count) items:
            \(subgraphStack.map(\.id).joined(separator: " -> "))
            """)
        }
    }

    /// Maps view controller instances to their corresponding navigation nodes.
    ///
    /// This mapping enables looking up the node associated with a view controller
    /// when handling completion callbacks or navigation delegate events.
    private var anyViewControllerToNode: [Int: AnyNavNode] = [:]

    /// Creates a new navigation controller with the specified graph and UIKit controller.
    ///
    /// - Parameters:
    ///   - graph: The navigation graph defining the application flow
    ///   - navigationController: The UIKit navigation controller for presenting screens
    ///
    /// ## Setup
    ///
    /// The initializer automatically configures the navigation controller as a delegate
    /// to handle navigation events like back button taps and swipe gestures.
    public init(
        graph: NavigationGraph,
        navigationController: UINavigationController
    ) {
        self.graph = graph
        self.navigationController = navigationController
        super.init()

        self.navigationController.delegate = self
    }

    /// Begins navigation at the specified node with the provided initial data.
    ///
    /// - Parameters:
    ///   - start: The starting navigation node
    ///   - data: The initial input data for the starting node
    ///
    /// ## Example
    ///
    /// ```swift
    /// navController.start(at: WelcomeNode(), with: ())
    /// ```
    ///
    /// ## Preconditions
    ///
    /// The starting node must be registered in the navigation graph, otherwise
    /// the method will crash with a fatal error.
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

    /// Presents a node on screen with the specified data and transition.
    ///
    /// This method handles both regular nodes and subgraphs, automatically
    /// switching context when entering nested navigation flows.
    ///
    /// - Parameters:
    ///   - node: The node to present
    ///   - data: The input data for the node
    ///   - incomingTransition: The transition type to use
    ///   - currentGraph: The graph context for resolving edges
    ///
    /// ## Subgraph Handling
    ///
    /// When the node represents a subgraph:
    /// 1. The subgraph is pushed onto the subgraph stack
    /// 2. Navigation switches to the subgraph's internal graph
    /// 3. The subgraph's start node is presented
    ///
    /// ## View Controller Creation
    ///
    /// For regular nodes:
    /// 1. Creates a view controller using the node's factory
    /// 2. Sets up completion callback handling
    /// 3. Presents using the specified transition type
    private func show(
        node: AnyNavNode,
        data: Any,
        incomingTransition: TransitionType,
        graph currentGraph: NavigationGraph
    ) {
        
        // Subgraph
        if let wrapper = node.subgraphWrapper {
            print("""
            ----------------------------
            [NAV]: entering subgraph \(wrapper.id) starting at \(wrapper.startNodeId)
            """)

            subgraphStack.append(node)
            print("[NAV DEBUG]: Pushed subgraph \(node.id) onto stack. Stack now: \(subgraphStack.map(\.id))")

            // Determine the start node of the subgraph.
            guard let startWrapped = wrapper.graph.nodes[wrapper.startNodeId] else {
                fatalError("Start node \(wrapper.startNodeId) is not registered in subgraph \(wrapper.id)")
            }

            // Begin the subgraph flow.  Use the subgraph's internal
            // graph when resolving edges for nodes inside the subgraph.
            // Pass the current subgraph node as the parent for nodes within this subgraph
            print("[NAV DEBUG]: Entering subgraph \(node.id), setting parentSubgraphNode to \(node.id) for start node \(startWrapped.id)")
            show(node: startWrapped, data: data, incomingTransition: incomingTransition, graph: wrapper.graph)
            return
        }

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
            nodeStack.removeLast()
        case .pop:
            // Should pop back to ancestor
            navigationController.popViewController(animated: true)
            nodeStack.removeLast()
        case .popTo(let index):

            if index == 0 {
                navigationController.popToRootViewController(animated: true)
                nodeStack.removeLast(navigationController.viewControllers.count - 1)
                return
            }

            fatalError("TODO: Need to implement popping to arbitrary point in stack")

            //let dropTotal = navigationController.viewControllers.count - index - 1
            //_ = navigationController.viewControllers.dropLast(dropTotal)
        case .push:
            navigationController.pushViewController(viewController, animated: true)
            
            print("[NAV DEBUG]: Adding node \(node.id) to stack with parentSubgraphNode: \(subgraphStack.last?.id ?? "nil")")
            nodeStack.append(StackItem(
                node: node,
                data: data,
                graph: currentGraph,
                incomingTransition: incomingTransition
            ))
        }
    }

    /// Handles completion of a view controller by finding the next navigation step.
    ///
    /// This method is called when a view controller invokes its completion handler.
    /// It evaluates outgoing edges from the current node and navigates to the next
    /// destination if an eligible edge is found.
    ///
    /// - Parameters:
    ///   - view: The view controller that completed
    ///   - output: The output data from the view controller
    ///
    /// ## Edge Evaluation Process
    ///
    /// 1. **Find outgoing edges**: Look up edges from the current node
    /// 2. **Filter by predicate**: Test each edge's predicate against the output data
    /// 3. **Choose first match**: Select the first edge whose predicate returns true
    /// 4. **Transform data**: Apply the edge's transform to prepare data for the destination
    /// 5. **Navigate**: Present the destination node with the transformed data
    ///
    /// ## Subgraph Exit Handling
    ///
    /// If no eligible edges are found in the current graph context, the method
    /// attempts to exit nested subgraphs and continue navigation in parent contexts.
    ///
    /// ## Modal Dismissal
    ///
    /// If the current view controller was presented modally, it's dismissed before
    /// presenting the next screen to avoid UIKit presentation conflicts.
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

        // Outgoing edges for the node in the appropriate graph.
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

        // Choose the first eligible edge.
        let chosen = candidates[0]

        // Compute the data for the next node using the edge's transform.
        let nextData = chosen.applyTransform(output)
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
    
    /// Attempts to exit the current subgraph and find navigation options in parent contexts.
    ///
    /// This method is called when no eligible edges are found in the current graph context.
    /// It recursively checks parent subgraphs to find valid navigation paths.
    ///
    /// - Parameters:
    ///   - node: The current node with no outgoing edges
    ///   - output: The output data from the current node
    ///   - view: The current view controller
    /// - Returns: `true` if navigation occurred, `false` if no valid exit was found
    ///
    /// ## Algorithm
    ///
    /// 1. **Check subgraph stack**: Verify there are subgraphs to exit
    /// 2. **Iterate parent contexts**: Try each subgraph level from innermost to outermost
    /// 3. **Find parent graph**: Determine the correct graph for edge resolution
    /// 4. **Evaluate edges**: Look for eligible edges from the subgraph node
    /// 5. **Navigate or continue**: Either navigate to a destination or try the next level
    ///
    /// ## Type Safety Note
    ///
    /// When exiting subgraphs, there can be type mismatches between the exiting node's
    /// output type and the subgraph's expected output type. The method handles this
    /// gracefully by passing the original output data.
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
                    graph: parentGraph
                )
                return true
            }
        }
        
        print("[NAV DEBUG]: No exit found at any level")
        return false
    }
    
    /// Determines the correct parent graph for a subgraph at a given nesting level.
    ///
    /// - Parameter index: The index in the subgraph stack (0 = outermost, count-1 = innermost)
    /// - Returns: The graph that contains edges from the subgraph at this level
    ///
    /// ## Graph Resolution Logic
    ///
    /// - **Outermost subgraph**: Parent is always the main navigation graph
    /// - **Nested subgraphs**: Parent is the internal graph of the subgraph one level up
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
    
    /// Finds an eligible edge for a node with given output data in the specified graph.
    ///
    /// - Parameters:
    ///   - node: The node to find edges for
    ///   - output: The output data to test against edge predicates
    ///   - graph: The graph to search for edges
    /// - Returns: The first eligible edge, or `nil` if none found
    ///
    /// ## Debug Output
    ///
    /// This method provides extensive debug logging to help track edge evaluation,
    /// including predicate results and type information.
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

            return result
        }
        
        print("[NAV DEBUG]: Found \(candidates.count) eligible edges for node \(node.id)")
        return candidates.first
    }
    
    /// Handles cleanup when nodes are removed from the navigation stack.
    ///
    /// This method is called when view controllers are popped or dismissed,
    /// ensuring that internal state remains consistent with the UIKit navigation stack.
    ///
    /// - Parameter view: The view controller that was removed
    private func handlePop(for view: UIViewController) {
        guard
            let navigableViewController = view as? any NavigableViewController,
            let poppedNode = anyViewControllerToNode[AnyNavigableViewController(navigableViewController).hash]
        else { return }
        anyViewControllerToNode[AnyNavigableViewController(navigableViewController).hash] = nil
        nodeStack.removeLast()

        print("""
        ------------------------------------
        [NAV]: popped node \(poppedNode.id). Current node is now \(nodeStack.last?.node.id ?? "none")
        """)

    }
}

// MARK: - UINavigationControllerDelegate

/// Extension conforming to `UINavigationControllerDelegate` to handle navigation events.
///
/// This delegate implementation detects when view controllers are popped by comparing
/// the transition coordinator's `fromVC` with the current navigation stack.
extension NavigationController: UINavigationControllerDelegate {
    
    /// Called when the navigation controller shows a new view controller.
    ///
    /// This method detects pop operations by checking if the previous view controller
    /// is no longer in the navigation stack.
    ///
    /// - Parameters:
    ///   - navController: The navigation controller
    ///   - viewController: The newly displayed view controller
    ///   - animated: Whether the transition was animated
    public func navigationController(
        _ navController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        // Determine if a view controller was popped by comparing the
        // transition coordinator's fromVC. If the fromVC is no longer
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

/// Extension conforming to `UIAdaptivePresentationControllerDelegate` to handle modal dismissal.
///
/// This delegate implementation detects when modals are dismissed interactively
/// (such as by swiping down) and updates the navigation state accordingly.
extension NavigationController: UIAdaptivePresentationControllerDelegate {

    /// Called when a modal presentation is dismissed interactively.
    ///
    /// This method treats interactive dismissal as equivalent to a pop operation,
    /// ensuring that the navigation state remains consistent.
    ///
    /// - Parameter presentationController: The presentation controller that was dismissed
    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        let dismissedVC = presentationController.presentedViewController
        handlePop(for: dismissedVC)
    }
}
