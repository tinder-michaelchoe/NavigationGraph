//
//  NavigationGraph.swift
//
//  Created by AI assistant as part of a demonstration of a type‑safe
//  navigation graph inspired by Android's Navigation component.  The goal
//  of this library is to provide a simple, idiomatic and maintainable
//  navigation graph for iOS/macOS projects written in Swift.  Nodes in
//  the graph represent screens (view controllers, SwiftUI views or
//  arbitrary presentation contexts), edges represent the legal
//  transitions between them, and data is passed along those edges in a
//  strongly‑typed manner.  Nested graphs are also supported via the
//  `NavSubgraph` type, allowing you to group related flows into
//  encapsulated subgraphs that can be reused throughout your app.
//
//  To use this library, create instances of `ScreenNode` for each of
//  your screens (or conform your own types to the `NavNode` protocol),
//  register them with a `NavigationGraph`, and then create `Edge`
//  instances describing how one screen can navigate to another.  You
//  can then query the graph for reachability, compute a path between
//  nodes, or pretty‑print a sequence of edges for debugging or
//  documentation purposes.

import Foundation
import UIKit

/*
 
 Things to ask ChatGPT
 - Can we make the onComplete closure strongly typed?
 - DSL for declaring Navigation Graphs
 - When presenting a modal, it should automaitcally create a new navigation controller and navigation graph.
 - Create a sample for a modal
 - Move the logging out of the view controllers and into the navigation controller
 - Rehydrating navigation stack
 - Creating navigation graphs from Codables
 - Deep linking into a certain point in a navigation stack
 - Restore functionality of awaitCompletion(). Each NavNode should be async.
 - Ability to register edges in priority. This may be helpful in ensuring that there will always be a valid flow.
 - Include check to make sure no nodes are repeated
 
 Presentation
 - My goal is to give a sandbox of tools that product, design, and data science can use.
 - The goal is that those desire should be the driving factor and the thing that should be the most scalable.
 - 
 
 
 */


// MARK: - Navigation graph

/// A `NavigationGraph` stores a collection of nodes and the edges
/// connecting them.  It supports adding nodes and edges, querying
/// reachability, computing paths between nodes and pretty‑printing
/// paths for debugging.  Nodes and edges may be registered in any
/// order; edges referencing nodes that have not yet been added will
/// assert when used but can be added to the adjacency map in advance.
public final class NavigationGraph {
    /// A dictionary mapping node identifiers to their erased node
    /// wrappers.  Each entry must be unique.  These members are
    /// `internal` rather than `private` to allow the navigation
    /// controller to inspect the graph when resolving flows.  They
    /// remain hidden from external modules because the entire file
    /// belongs to the same module.
    var nodes: [String: AnyNavNode] = [:]
    /// An adjacency map from node identifiers to their outgoing
    /// edges.  Edges may be registered before the corresponding
    /// nodes, but will only be usable once both nodes are present.
    var adjacency: [String: [AnyNavEdge]] = [:]

    /// Initializes an empty navigation graph.
    public init() {}

    // MARK: Node registration

    /// Adds a node to the graph.  If a node with the same id already
    /// exists, this method will replace it.  It is safe to add a
    /// node after registering edges; once both the source and
    /// destination nodes of an edge exist, that edge becomes valid.
    @discardableResult
    public func addNode<N: NavNode>(_ node: N) -> Self {
        #if DEBUG
        if nodes[node.id] != nil {
            fatalError("Node already exists in this graph. Check your registrations.")
        }
        #endif
        let wrapped = AnyNavNode(node)
        nodes[node.id] = wrapped
        if adjacency[node.id] == nil {
            adjacency[node.id] = []
        }
        return self
    }

    /// Adds a subgraph as a node in this graph.  The subgraph is
    /// represented as a single node whose `DataType` matches the
    /// `DataType` of its start node.  Once added, you can connect
    /// edges to and from the subgraph just like any other node.  To
    /// navigate within the subgraph, call `findPath` on the
    /// subgraph's internal `NavigationGraph`.
    @discardableResult
    public func addSubgraph<Start: NavNode>(_ subgraph: NavSubgraph<Start>) -> Self {
        let wrapped = AnyNavNode(subgraph)
        nodes[subgraph.id] = wrapped
        if adjacency[subgraph.id] == nil {
            adjacency[subgraph.id] = []
        }
        return self
    }

    // MARK: Edge registration

    /// Adds a directed edge to the graph.  Both the source and
    /// destination nodes must eventually be added to the graph for
    /// navigation to be valid.  The graph does not check that the
    /// nodes exist at the time of registration; however, runtime
    /// errors will occur if navigation is attempted between nodes that
    /// have not been registered.
    @discardableResult
    public func addEdge<From: NavNode, To: NavNode>(_ edge: Edge<From, To>) -> Self {
        let list = adjacency[edge.from.id] ?? []
        let fromWrapped: AnyNavNode
        if let existingFrom = nodes[edge.from.id] {
            fromWrapped = existingFrom
        } else {
            let placeholder = ScreenNode<From.InputType, From.OutputType>(edge.from.id)
            fromWrapped = AnyNavNode(placeholder)
        }
        let toWrapped: AnyNavNode
        if let existingTo = nodes[edge.to.id] {
            toWrapped = existingTo
        } else {
            let placeholder = ScreenNode<To.InputType, To.OutputType>(edge.to.id)
            toWrapped = AnyNavNode(placeholder)
        }
        let anyEdge = AnyNavEdge(edge, from: fromWrapped, to: toWrapped)
        adjacency[edge.from.id] = list + [anyEdge]
        return self
    }

    // MARK: Reachability and path finding

    /// Returns a boolean indicating whether a path exists between the
    /// specified source and destination nodes.  If either node is not
    /// registered in the graph, the function returns `false`.
    public func canNavigate(from sourceId: String, to destinationId: String) -> Bool {
        return findPath(from: sourceId, to: destinationId) != nil
    }

    /// Returns a boolean indicating whether a path exists between the
    /// specified source and destination nodes.  Generic overload that
    /// accepts node instances directly.
    public func canNavigate<From: NavNode, To: NavNode>(from source: From, to destination: To) -> Bool {
        return canNavigate(from: source.id, to: destination.id)
    }

    /// Finds a path from the node with id `sourceId` to the node
    /// `destinationId` using breadth‑first search.  Returns an array
    /// of erased edges representing the path, or `nil` if no path
    /// exists.  Nested subgraphs are treated as atomic nodes; this
    /// implementation does not automatically descend into a subgraph's
    /// internal graph.
    public func findPath(from sourceId: String, to destinationId: String) -> [AnyNavEdge]? {
        guard nodes[sourceId] != nil, nodes[destinationId] != nil else {
            return nil
        }
        var visited: Set<String> = []
        var queue: [(String, [AnyNavEdge])] = [(sourceId, [])]
        visited.insert(sourceId)
        while !queue.isEmpty {
            let (currentId, path) = queue.removeFirst()
            if currentId == destinationId {
                return path
            }
            let edges = adjacency[currentId] ?? []
            for edge in edges {
                let nextId = edge.toNode.id
                if !visited.contains(nextId) {
                    visited.insert(nextId)
                    queue.append((nextId, path + [edge]))
                }
            }
        }
        return nil
    }

    /// Generic overload of `findPath` that accepts node instances
    /// directly.  Returns a typed array of erased edges representing
    /// the path, or `nil` if no path exists.
    public func findPath<From: NavNode, To: NavNode>(from source: From, to destination: To) -> [AnyNavEdge]? {
        return findPath(from: source.id, to: destination.id)
    }
    
    // MARK: - Graph Helpers
    
    func hasNode<Node: NavNode>(_ node: Node) -> Bool {
        return nodes.contains(where: { $0.key == node.id })
    }

    // MARK: Pretty printing

    /// Returns a human‑readable description of the provided path.  Each
    /// edge is formatted as `fromId --(transition)--> toId`.  If the
    /// path is empty, an empty string is returned.
    public func prettyPrintPath(_ path: [AnyNavEdge]) -> String {
        guard !path.isEmpty else { return "" }
        return path.map { edge in
            "\(edge.fromNode.id) --(\(edge.transition))--> \(edge.toNode.id)"
        }.joined(separator: "\n")
    }
}

// MARK: - Subgraphs

/// A `NavSubgraph` encapsulates a nested navigation graph.  It
/// conforms to `NavNode` so that the subgraph itself can act as a
/// node in a parent graph.  The `InputType` of the subgraph is the
/// same as the `InputType` of its start node, and the `OutputType` of
/// the subgraph is the same as the `OutputType` of its start node.
public final class NavSubgraph<Start: NavNode>: NavNode {
    public typealias InputType = Start.InputType
    public typealias OutputType = Start.OutputType
    /// The identifier for the subgraph.  This identifier must be
    /// unique within the parent graph.
    public let id: String
    /// The internal navigation graph containing the nested flow.
    public let graph: NavigationGraph
    /// The identifier of the start node within the internal graph.
    public let startNodeId: String

    /// Creates a new nested graph with the provided identifier,
    /// internal graph and start node.  The caller is responsible for
    /// ensuring that the start node exists within the internal graph
    /// and that the subgraph id is unique within the parent graph.
    public init(id: String, graph: NavigationGraph, start: Start) {
        self.id = id
        self.graph = graph
        self.startNodeId = start.id
    }
}

/// A protocol that view controllers used by `NavigationController` must
/// conform to.  It exposes an `onComplete` callback which should be
/// invoked when the user has finished interacting with the screen.  The
/// parameter to `onComplete` is the data returned from the screen; it
/// must match the node's `OutputType`. `NavigationController` uses
/// this callback to resume navigation.
public protocol NavigableViewController: UIViewController {
    /// Call this closure when the view controller's work is
    /// complete.  Pass back any data produced by the screen.
    var onComplete: ((Any) -> Void)? { get set }
}


/*
// Provide a default async method for awaiting completion of a
// navigable view controller.  This helper hides the use of
// continuations so that callers can use async/await syntax
// directly.  The returned value is the data passed to the
// `onComplete` closure.
extension NavigableViewController {
    /// Waits asynchronously until the user completes this screen and
    /// invokes the `onComplete` callback.  The returned value is
    /// whatever was supplied to the callback.  You should call
    /// `awaitCompletion()` only after presenting the view controller.
    public func awaitCompletion() async -> Any {
        return await withCheckedContinuation { (continuation: CheckedContinuation<Any, Never>) in
            // Track whether the continuation has already been resumed.
            var resumed = false
            // Assign the completion handler.  If the handler is invoked
            // more than once (e.g. due to both the user tapping "Next"
            // and then navigating back), only resume the continuation
            // the first time.  Subsequent invocations are ignored.
            self.onComplete = { data in
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: data)
            }
        }
    }
}
 */

/// A protocol that abstracts over `NavSubgraph` without exposing its
/// generic type.  It provides access to the nested graph and the
/// start node identifier, enabling runtime operations on subgraphs
/// without knowing their concrete `Start` type.  `NavSubgraph`
/// conforms to this protocol; clients should not implement this
/// protocol themselves.
public protocol NavSubgraphProtocol {
    /// The identifier of the subgraph.  Equivalent to `id` on
    /// `NavSubgraph`.
    var id: String { get }
    /// The nested navigation graph associated with the subgraph.
    var graph: NavigationGraph { get }
    /// The identifier of the start node within the nested graph.
    var startNodeId: String { get }
}

extension NavSubgraph: NavSubgraphProtocol {}

#if DEBUG
// MARK: - Testability Helpers and Graph Validation

/// Represents a step taken during a test navigation dry run.
public struct NavigationStep {
    public let from: String
    public let to: String
    public let transition: TransitionType
    public let output: Any
    public let input: Any
}

public extension NavigationGraph {
    enum GraphError: Error {
        case error(message: String)
    }
}

public extension NavigationGraph {
    /// Simulate navigation from a start node, feeding outputs for each step.
    /// Returns the path traversed, or an error if navigation gets stuck.
    func dryRun(
        from startId: String,
        initialInput: Any,
        outputProvider: (String, Any) -> Any, // (nodeId, lastInput) -> nextOutput
        stopAt: ((String) -> Bool)? = nil,
        maxHops: Int = 32
    ) throws -> [NavigationStep] {
        guard nodes[startId] != nil else { throw GraphError.error(message: "Start node \(startId) not found") }
        var steps: [NavigationStep] = []
        var currentId = startId
        var lastOutput: Any = initialInput
        var hops = 0
        while hops < maxHops, let edges = adjacency[currentId], !edges.isEmpty {
            let eligible = edges.first(where: { $0.predicateAny(lastOutput) })
            guard let edge = eligible else { break }
            let inputForNext = edge.applyTransform(lastOutput)
            steps.append(NavigationStep(
                from: currentId,
                to: edge.toNode.id,
                transition: edge.transition,
                output: lastOutput,
                input: inputForNext
            ))
            if let stop = stopAt, stop(edge.toNode.id) { break }
            currentId = edge.toNode.id
            lastOutput = outputProvider(currentId, inputForNext)
            hops += 1
        }
        if hops >= maxHops {
            throw GraphError.error(message: "Navigation exceeded \(maxHops) hops (possible cycle?)")
        }
        return steps
    }

    /// Asserts that a path exists and matches the expected sequence.
    func assertPath(
        from startId: String,
        to endId: String,
        expectedTransitions: [TransitionType]? = nil
    ) throws -> [String] {
        guard let path = findPath(from: startId, to: endId) else {
            throw GraphError.error(message: "No path from \(startId) to \(endId)")
        }
        if let expected = expectedTransitions {
            let actual = path.map { $0.transition }
            guard actual == expected else {
                throw GraphError.error(message: "Transitions did not match. Expected: \(expected), Actual: \(actual)")
            }
        }
        return path.map { $0.toNode.id }
    }

    /// Returns a set of node IDs that cannot be reached from any other node.
    func unreachableNodes() -> Set<String> {
        var reachable = Set<String>()
        for (_, edges) in adjacency {
            for edge in edges {
                reachable.insert(edge.toNode.id)
            }
        }
        return Set(nodes.keys).subtracting(reachable)
    }

    /// Detect cycles in the graph (useful if cycles are prohibited).
    func containsCycle() -> Bool {
        var visited = Set<String>()
        var stack = Set<String>()
        func visit(nodeId: String) -> Bool {
            if stack.contains(nodeId) { return true }
            if visited.contains(nodeId) { return false }
            visited.insert(nodeId)
            stack.insert(nodeId)
            for edge in adjacency[nodeId] ?? [] {
                if visit(nodeId: edge.toNode.id) {
                    return true
                }
            }
            stack.remove(nodeId)
            return false
        }
        for id in nodes.keys {
            if visit(nodeId: id) {
                return true
            }
        }
        return false
    }

    /// Validate edge type compatibility (stub for future expansion).
    /// Here as a placeholder, as runtime type information with `Any` is limited.
    func validateEdgeTypes() -> [String] {
        // Not implemented due to Swift's type erasure with Any—could expand with custom test values or code generation.
        return []
    }
}
#endif
