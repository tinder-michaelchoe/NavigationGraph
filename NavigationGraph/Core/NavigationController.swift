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
    fileprivate enum StackEntry {
        case screen(node: AnyNavNode, data: Any, graph: NavigationGraph, incoming: TransitionType, uiHash: Int)
        case headless(node: AnyNavNode, data: Any, graph: NavigationGraph, incoming: TransitionType)
        case subgraph(node: AnyNavNode, parentGraph: NavigationGraph, internalGraph: NavigationGraph)
    }
    
    /// Lightweight dummy controller that conforms to NavigableViewController for headless nodes.
    private final class DummyHeadlessViewController: UIViewController, NavigableViewController {
        typealias CompletionType = Any
        var onComplete: ((Any) -> Void)?
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
    private var nodeStack: [StackEntry] = [] {
        didSet {
            print("""
            -------------
            [NAV]: Stack now contains \(nodeStack.count) items:
            \(nodeStack.map(\.node.id).joined(separator: " -> "))
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
            [NAV]: entering subgraph \(wrapper.id) starting at \(wrapper.entryNodeId)
            """)

            nodeStack.append(.subgraph(node: node, parentGraph: currentGraph, internalGraph: wrapper.graph))

            // Determine the entry node of the subgraph and start navigation inside it
            guard let entryWrapped = wrapper.graph.nodes[wrapper.entryNodeId] else {
                fatalError("Entry node \(wrapper.entryNodeId) is not registered in subgraph \(wrapper.id)")
            }
            show(node: entryWrapped, data: data, incomingTransition: incomingTransition, graph: wrapper.graph)
            return
        }

        // Handle headless nodes immediately without presenting UI
        if let processor = node.anyHeadlessProcessor {
            // Push onto the stack to preserve navigation context
            nodeStack.append(
                .headless(
                    node: node,
                    data: data,
                    graph: currentGraph,
                    incoming: incomingTransition
                )
            )

            let output = processor.transformAny(data)

            // Use a dummy navigable controller for consistent completion handling
            let dummy = DummyHeadlessViewController()
            anyViewControllerToNode[AnyNavigableViewController(dummy).hash] = node
            handleCompletion(from: dummy, output: output)
            return
        }

        // Handle UI-providing nodes
        guard
            let anyViewControllerProviding = node.anyViewControllerProviding,
            let viewController = anyViewControllerProviding.viewControllerFactory(data).wrapped as? (any NavigableViewController)
        else {
            fatalError("Couldn't find view controller provider or headless processor.")
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

            nodeStack.append(
                .screen(
                    node: node,
                    data: data,
                    graph: currentGraph,
                    incoming: incomingTransition,
                    uiHash: AnyNavigableViewController(viewController).hash
                )
            )
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
            
            print("[NAV DEBUG]: Adding node \(node.id) to stack")
            nodeStack.append(
                .screen(
                    node: node,
                    data: data,
                    graph: currentGraph,
                    incoming: incomingTransition,
                    uiHash: AnyNavigableViewController(viewController).hash
                )
            )
        }
        reconcile(caller: "show(node:)")
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
        let currentGraph = currentEntry.graphContext
        let incoming = currentEntry.incomingTransition ?? .push

        // Proactively exit subgraph if we're on its explicit exit node
        if let subIdx = nodeStack.lastIndex(where: { $0.isSubgraph }),
           case let .subgraph(subgraphNode, _, internalGraph) = nodeStack[subIdx],
           let wrapper = subgraphNode.subgraphWrapper,
           currentGraph === internalGraph,
           wrapper.exitNodeId == node.id {
            if tryExitSubgraph(for: subgraphNode, with: output, from: view) { return }
        }

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
        guard let sentinelIndex = nodeStack.lastIndex(where: { $0.isSubgraph }) else {
            print("[NAV DEBUG]: Not at a subgraph sentinel, cannot exit")
            return false
        }
        let entry = nodeStack[sentinelIndex]
guard case let .subgraph(subgraphNode, parentGraph, _) = entry else {
            print("[NAV DEBUG]: Subgraph entry malformed, cannot exit")
            return false
        }
        // Use the subgraph node found
        print("[NAV DEBUG]: Checking if we can exit subgraph \(subgraphNode.id) into parent graph")
        print("[NAV DEBUG]: Current node output type: \(type(of: output)), value: \(output)")

        let subgraphEdges = parentGraph.adjacency[subgraphNode.id] ?? []
        print("[NAV DEBUG]: Subgraph \(subgraphNode.id) has \(subgraphEdges.count) outgoing edges in parent graph")

        let subgraphOutput: Any = output
        print("[NAV DEBUG]: Using original output (\(type(of: output))) for subgraph edge predicate evaluation")

        if let edge = findEligibleEdge(for: subgraphNode, with: subgraphOutput, in: parentGraph) {
            print("""
            -----------------------------------
            [NAV]: Found exit! Exiting subgraph \(subgraphNode.id)
            \(subgraphNode.id) --|\(edge.transition)|--> \(edge.toNode.id)
            """)

            // Remove the subgraph sentinel from the stack
            nodeStack.remove(at: sentinelIndex)
            print("[NAV DEBUG]: Removed subgraph sentinel from stack")

            // Navigate to the destination in the parent graph
            show(
                node: edge.toNode,
                data: edge.applyTransform(output),
                incomingTransition: edge.transition,
                graph: parentGraph
            )
            return true
        }

        print("[NAV DEBUG]: No exit found at current sentinel level")
        return false
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
        // Remove the last screen entry
        if let idx = nodeStack.lastIndex(where: { entry in
            if case let .screen(node, _, _, _, uiHash) = entry {
                return node.id == poppedNode.id && uiHash == AnyNavigableViewController(navigableViewController).hash
            }
            return false
        }) {
            nodeStack.remove(at: idx)
        } else {
            nodeStack.removeLast()
        }

        // If the next item on the stack is a headless node (which has no UIKit VC),
        // remove consecutive headless nodes to keep internal stack in sync with UIKit's.
        while let last = nodeStack.last, last.uiControllerHash == nil {
            print("[NAV]: Removing non-UI stack entry \(last.node.id) to sync with UI stack")
            nodeStack.removeLast()
        }

        // Synchronize subgraph sentinels with current graph context
        let currentGraphContext = nodeStack.last?.graphContext ?? self.graph
        while let last = nodeStack.last, last.isSubgraph, let parent = last.parentGraphForSubgraph {
            if parent === currentGraphContext { break }
            print("[NAV]: Exiting subgraph sentinel to sync with UI stack")
            nodeStack.removeLast()
        }

        print("""
        ------------------------------------
        [NAV]: popped node \(poppedNode.id). Current node is now \(nodeStack.last?.node.id ?? "none")
        """)

    }

    // MARK: - Reconciliation to keep UIKit, nodeStack, and subgraphStack in sync
    private func reconcile(caller: String) {
        #if DEBUG
        print("[NAV RECONCILE] invoked by: \(caller)")
        #endif

        // 1) Determine the active anchor VC: presented modal or top of nav stack
        let anchorVC: UIViewController? = navigationController.presentedViewController ?? navigationController.topViewController

        // 2) Prune nodeStack to anchor
        if let anchorVC {
            // Find the matching StackItem by uiControllerHash if available; fallback to mapping
            let anchorHash = anchorVC is AnyNavigableViewController ? anchorVC.hash : anchorVC.hash
            if let idx = nodeStack.lastIndex(where: { $0.uiControllerHash == anchorHash }) {
                // Trim any items above idx
                if idx < nodeStack.count - 1 { nodeStack.removeLast(nodeStack.count - 1 - idx) }
            } else if let mappedNode = anyViewControllerToNode[anchorVC.hash] {
                if let idx = nodeStack.lastIndex(where: { $0.node.id == mappedNode.id }) {
                    if idx < nodeStack.count - 1 { nodeStack.removeLast(nodeStack.count - 1 - idx) }
                }
            }
        } else {
            // No anchor VC; if we still have stack entries with UI, trim to none
            // Keep at most trailing headless nodes only if desired; simplest: clear stack
            // But prefer to leave root if appropriate. For now, do nothing.
        }

        // Fallback: ensure no non-UI entries remain above last on-screen UI entry
        if let lastScreenIdx = nodeStack.lastIndex(where: { $0.uiControllerHash != nil }) {
            if lastScreenIdx < nodeStack.count - 1 {
                nodeStack.removeLast(nodeStack.count - 1 - lastScreenIdx)
            }
        } else {
            // No screens in the stack → drop all non-UI entries
            if !nodeStack.isEmpty { nodeStack.removeAll() }
        }

        // 3) Remove trailing headless nodes after a pop
        while let last = nodeStack.last, last.uiControllerHash == nil {
            print("[NAV]: Removing trailing headless node \(last.node.id) during reconcile")
            nodeStack.removeLast()
        }

        // 4) Sync subgraphStack with current graph context
        let currentGraphContext = nodeStack.last?.graphContext ?? self.graph
        while let last = nodeStack.last, last.isSubgraph, let parent = last.parentGraphForSubgraph {
            if parent === currentGraphContext { break }
            print("[NAV]: Exiting subgraph sentinel during reconcile")
            nodeStack.removeLast()
        }

        // 5) DEBUG invariants
        #if DEBUG
        let uiHashes = navigationController.viewControllers.map { $0.hash }
        let stackHashes = nodeStack.compactMap { $0.uiControllerHash }
        if uiHashes != stackHashes {
            print("[NAV WARN]: UI stack hashes != internal stack hashes\nUI: \(uiHashes)\nIN: \(stackHashes)")
        }
        #endif
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
        reconcile(caller: "navigationController(didShow:)")
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
        reconcile(caller: "presentationControllerDidDismiss(_:)")
    }
}

private extension NavigationController.StackEntry {
    var node: AnyNavNode {
        switch self {
        case .screen(let node, _, _, _, _): return node
        case .headless(let node, _, _, _): return node
        case .subgraph(let node, _, _): return node
        }
    }
    var graphContext: NavigationGraph {
        switch self {
        case .screen(_, _, let graph, _, _): return graph
        case .headless(_, _, let graph, _): return graph
        case .subgraph(_, _, let internalGraph): return internalGraph
        }
    }
    var incomingTransition: TransitionType? {
        switch self {
        case .screen(_, _, _, let incoming, _): return incoming
        case .headless(_, _, _, let incoming): return incoming
        case .subgraph: return nil
        }
    }
    var uiControllerHash: Int? {
        switch self {
        case .screen(_, _, _, _, let uiHash): return uiHash
        case .headless: return nil
        case .subgraph: return nil
        }
    }
    var isHeadless: Bool {
        if case .headless = self { return true } else { return false }
    }
    var isSubgraph: Bool {
        if case .subgraph = self { return true } else { return false }
    }
    var parentGraphForSubgraph: NavigationGraph? {
        if case .subgraph(_, let parent, _) = self { return parent } else { return nil }
    }
    var internalGraphForSubgraph: NavigationGraph? {
        if case .subgraph(_, _, let internalGraph) = self { return internalGraph } else { return nil }
    }
}
