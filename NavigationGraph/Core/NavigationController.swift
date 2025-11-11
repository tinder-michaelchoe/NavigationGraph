//
//  NavigationController.swift
//  NavigationGraph
//
//  Created by mexicanpizza on 7/29/25.
//

import UIKit
import ObjectiveC

// MARK: - Pluggable node presentation

/// A handler capable of producing a presentable UI for a given node.
///
/// Implementations may wrap SwiftUI views, vend `UIViewController`s,
/// or adapt custom presentation mechanisms. The handler must call the provided
/// `onComplete` closure when the node's work is done.
public protocol NodePresentationHandler {

    func canHandle(nodeType: Any.Type) -> Bool
    func makeViewController(
        for node: AnyNavNode,
        input: Any,
        onComplete: @escaping (Any) -> Void
    ) -> UIViewController?
}

/// Default handler for nodes that vend a `UIViewController` via `ViewControllerProviding`.
struct DefaultUIKitNodeHandler: NodePresentationHandler {

    //func canHandle(node: AnyNavNode) -> Bool {
    func canHandle(nodeType: Any.Type) -> Bool {
        //node.anyViewControllerProviding != nil
        return true
    }

    func makeViewController(
        for node: AnyNavNode,
        input: Any,
        onComplete: @escaping (Any) -> Void
    ) -> UIViewController? {
        guard let provider = node.anyViewControllerProviding else {
            return nil
        }
        let anyVC = provider.viewControllerFactory(input)
        // Wire completion into the underlying VC
        anyVC.onComplete = onComplete
        // Present the underlying UIViewController, not the wrapper
        guard let base = anyVC.wrapped as? UIViewController else {
            return nil
        }
        return base
    }
}

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
        case subgraph(node: AnyNavNode, parentGraph: NavigationGraph, internalGraph: NavigationGraph)
    }

    fileprivate struct AssociatedNavigation {
        let node: AnyNavNode
        let graph: NavigationGraph
        let subgraphTrail: [SubgraphFrame]
        let incoming: TransitionType
    }

    fileprivate struct SubgraphFrame {
        let node: AnyNavNode
        let parent: NavigationGraph
        let internalGraph: NavigationGraph
    }

    private struct NextResolution {
        let edge: AnyNavEdge
        let graph: NavigationGraph
        let nextData: Any
        let nextTrail: [SubgraphFrame]
        let source: AnyNavNode
    }

    private enum NavigationCommand {
        case clearStackAndSet(UIViewController, meta: AssociatedNavigation)
        case dismiss
        case modal(UIViewController, meta: AssociatedNavigation)
        case pop
        case popTo(Int)
        case push(UIViewController, meta: AssociatedNavigation)
    }

    /// The top-level navigation graph describing the application flow.
    private let graph: NavigationGraph
    
    /// The UIKit navigation controller used to present view controllers.
    private let navigationController: UINavigationController
    
    /// Handlers used to render nodes into presentable UI.
    private let handlers: [NodePresentationHandler]
    
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
        navigationController: UINavigationController,
        handlers: [NodePresentationHandler]
    ) {
        self.graph = graph
        self.navigationController = navigationController
        self.handlers = handlers
        super.init()
        self.navigationController.delegate = self
    }

    /// Convenience initializer that installs a default UIKit handler.
    public convenience init(
        graph: NavigationGraph,
        navigationController: UINavigationController
    ) {
        self.init(graph: graph, navigationController: navigationController, handlers: [DefaultUIKitNodeHandler()])
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
        visit(node: wrapped, data: data, in: graph, incoming: .push, subgraphTrail: [])
    }

    // MARK: - Unified visit entry

    // Convenience method
    private func visit(next: NextResolution) {
        visit(
            node: next.edge.toNode,
            data: next.nextData,
            in: next.graph,
            incoming: next.edge.transition,
            subgraphTrail: next.nextTrail
        )
    }

    private func visit(
        node: AnyNavNode,
        data: Any,
        in currentGraph: NavigationGraph,
        incoming: TransitionType,
        subgraphTrail: [SubgraphFrame]
    ) {
        // Enter subgraph nodes immediately
        if let wrapper = node.subgraphWrapper {
            print("""
            ----------------------------
            [NAV]: entering subgraph \(wrapper.id) starting at \(wrapper.entryNodeId)
            """)
            guard let entryWrapped = wrapper.graph.nodes[wrapper.entryNodeId] else {
                fatalError("Entry node \(wrapper.entryNodeId) is not registered in subgraph \(wrapper.id)")
            }
            var nextTrail = subgraphTrail
            nextTrail.append(SubgraphFrame(node: node, parent: currentGraph, internalGraph: wrapper.graph))
            visit(node: entryWrapped, data: data, in: wrapper.graph, incoming: incoming, subgraphTrail: nextTrail)
        } else if let headless = node.anyHeadlessProcessor {
            // Headless nodes are processed immediately and do not appear on the UI stack
            let output = headless.transformAny(data)
            if let resolved = resolveNext(from: node, output: output, startingIn: currentGraph, trail: subgraphTrail) {
                print("""
                -----------------------------------
                \(resolved.source.fullyQualifiedId) --|\(resolved.edge.transition)|--> \(resolved.edge.toNode.fullyQualifiedId)
                Input data: \(output)
                Transformed data: \(resolved.nextData)
                """)
                dispatch(resolution: resolved, incoming: incoming)
                return
            } else {
                print("""
                -----------------------------------
                [NAV]: No eligible edges found for headless node \(node.fullyQualifiedId)
                """)
            }
        } else {
            // UI-providing nodes → build via handler, attach metadata, execute transition
            guard let viewController = makeViewController(
                for: node,
                input: data,
                trail: subgraphTrail,
                graph: currentGraph,
                incoming: incoming
            ) else {
                fatalError("No handler could present node \(node.id)")
            }

            let meta = AssociatedNavigation(node: node, graph: currentGraph, subgraphTrail: subgraphTrail, incoming: incoming)
            switch incoming {
            case .clearStackAndSet:
                execute(.clearStackAndSet(viewController, meta: meta))
            case .dismiss:
                execute(.dismiss)
            case .modal:
                execute(.modal(viewController, meta: meta))
            case .none:
                break
            case .pop:
                execute(.pop)
            case .popTo(let index):
                execute(.popTo(index))
            case .push:
                execute(.push(viewController, meta: meta))
            }
        }
    }

    // MARK: - Decision layer (pure resolver)
    private func resolveNext(
        from node: AnyNavNode,
        output: Any,
        startingIn graph: NavigationGraph,
        trail: [SubgraphFrame]
    ) -> NextResolution? {
        // Try within current graph using the node itself
        if let edge = findEligibleEdge(for: node, with: output, in: graph) {
            return NextResolution(
                edge: edge,
                graph: graph,
                nextData: edge.applyTransform(output),
                nextTrail: trail,
                source: node
            )
        }
        // Climb out through subgraph sentinels
        var tempTrail = trail
        while let last = tempTrail.last {
            if let edge = findEligibleEdge(for: last.node, with: output, in: last.parent) {
                let nextTrail = tempTrail.dropLast()
                return NextResolution(
                    edge: edge,
                    graph: last.parent,
                    nextData: edge.applyTransform(output),
                    nextTrail: Array(nextTrail),
                    source: last.node
                )
            }
            tempTrail.removeLast()
        }
        return nil
    }

    // MARK: - Unified transition dispatcher
    private func dispatch(resolution: NextResolution, incoming: TransitionType) {
        // Backward navigation commands
        switch resolution.edge.transition {
        case .pop:
            execute(.pop)
            return
        case .popTo(let idx):
            execute(.popTo(idx))
            return
        case .dismiss:
            execute(.dismiss)
            return
        default:
            break
        }
        // Forward navigation; if current was modal, dismiss before visiting next
        if incoming == .modal {
            navigationController.dismiss(animated: true) { [weak self] in
                guard let self else { return }
                visit(next: resolution)
            }
        } else {
            visit(next: resolution)
        }
    }

    // MARK: - Execution layer (commands)
    @MainActor
    private func execute(_ command: NavigationCommand) {
        switch command {
        case .clearStackAndSet(let viewController, let meta):
            viewController.navAssociatedNavigation = meta
            navigationController.setViewControllers([viewController], animated: true)
        case .dismiss:
            navigationController.dismiss(animated: true)
        case .modal(let viewController, let meta):
            viewController.navAssociatedNavigation = meta
            if !(viewController is UIAlertController) {
                viewController.presentationController?.delegate = self
            }
            navigationController.present(viewController, animated: true)
        case .pop:
            navigationController.popViewController(animated: true)
        case .popTo(let index):
            if index == 0 {
                navigationController.popToRootViewController(animated: true)
            } else {
                let viewControllers = navigationController.viewControllers
                if index < viewControllers.count {
                    navigationController.popToViewController(viewControllers[index], animated: true)
                }
            }
        case .push(let viewController, let meta):
            viewController.navAssociatedNavigation = meta
            navigationController.pushViewController(viewController, animated: true)
        }
        rebuildStateFromUI()
    }

    // MARK: - VC building via handlers
    private func makeViewController(
        for node: AnyNavNode,
        input: Any,
        trail: [SubgraphFrame],
        graph: NavigationGraph,
        incoming: TransitionType
    ) -> UIViewController? {
        guard let handler = handlers.first(where: { handler in
            let nodeType = type(of: node.wrappedNode)
            return handler.canHandle(nodeType: nodeType)
        }) else { return nil }
        let viewController = handler.makeViewController(for: node, input: input) { [weak self] output in
            guard let self else { return }
            if let resolved = resolveNext(from: node, output: output, startingIn: graph, trail: trail) {
                print("""
                -----------------------------------
                \(resolved.source.fullyQualifiedId) --|\(resolved.edge.transition)|--> \(resolved.edge.toNode.fullyQualifiedId)
                Input data: \(output)
                Transformed data: \(resolved.nextData)
                """)
                dispatch(resolution: resolved, incoming: incoming)
            } else {
                print("""
                -----------------------------------
                [NAV]: No eligible edges found for \(node.fullyQualifiedId), staying on current screen
                """)
            }
        }
        guard let viewController else {
            fatalError("No View Controller")
        }
        return viewController
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
    
    /// Rebuild nodeStack from the UIKit stack as the sole source of truth.
    private func rebuildStateFromUI() {
        nodeStack.removeAll(keepingCapacity: true)
        var appliedTrail: [SubgraphFrame] = []
        for vc in navigationController.viewControllers {
            guard let meta = vc.navAssociatedNavigation else { continue }
            // Longest common prefix between appliedTrail and meta.subgraphTrail
            var i = 0
            while i < appliedTrail.count && i < meta.subgraphTrail.count {
                let a = appliedTrail[i]
                let b = meta.subgraphTrail[i]
                if a.node.id == b.node.id { i += 1 } else { break }
            }
            if appliedTrail.count > i { nodeStack.removeLast(appliedTrail.count - i) }
            appliedTrail = Array(appliedTrail.prefix(i))
            for j in i..<meta.subgraphTrail.count {
                let s = meta.subgraphTrail[j]
                nodeStack.append(.subgraph(node: s.node, parentGraph: s.parent, internalGraph: s.internalGraph))
                appliedTrail.append(s)
            }
            // Append the screen entry
            nodeStack.append(.screen(node: meta.node, data: (), graph: meta.graph, incoming: meta.incoming, uiHash: vc.hash))
        }
        #if DEBUG
        print("[NAV]: Rebuilt nodeStack from UI")
        print(nodeStack.map(\.node.id).joined(separator: " -> "))
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
        // A VC was popped; rebuild from UI source of truth
        rebuildStateFromUI()
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
        rebuildStateFromUI()
    }
}

// MARK: - UIViewController associated navigation metadata
private extension UIViewController {
    struct _NavAssocKeys {
        static var navMetaKey: UInt8 = 0
    }
    var navAssociatedNavigation: NavigationController.AssociatedNavigation? {
        get { objc_getAssociatedObject(self, &_NavAssocKeys.navMetaKey) as? NavigationController.AssociatedNavigation }
        set { objc_setAssociatedObject(self, &_NavAssocKeys.navMetaKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

private extension NavigationController.StackEntry {
    var node: AnyNavNode {
        switch self {
        case .screen(let node, _, _, _, _):
            return node

        case .subgraph(let node, _, _):
            return node
        }
    }
    var graphContext: NavigationGraph {
        switch self {
        case .screen(_, _, let graph, _, _):
            return graph

        case .subgraph(_, _, let internalGraph):
            return internalGraph
        }
    }
    var incomingTransition: TransitionType? {
        switch self {
        case .screen(_, _, _, let incoming, _):
            return incoming

        case .subgraph:
            return nil
        }
    }
    var uiControllerHash: Int? {
        switch self {
        case .screen(_, _, _, _, let uiHash):
            return uiHash

        case .subgraph:
            return nil
        }
    }
    var isHeadless: Bool { false }
    var isSubgraph: Bool {
        if case .subgraph = self {
            return true
        } else {
            return false
        }
    }
    var parentGraphForSubgraph: NavigationGraph? {
        if case .subgraph(_, let parent, _) = self {
            return parent
        } else {
            return nil
        }
    }
    var internalGraphForSubgraph: NavigationGraph? {
        if case .subgraph(_, _, let internalGraph) = self {
            return internalGraph
        } else {
            return nil
        }
    }
}
