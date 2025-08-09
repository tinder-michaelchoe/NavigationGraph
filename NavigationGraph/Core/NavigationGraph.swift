//
//  NavigationGraph.swift
//

import Foundation
import UIKit

/*
 
Feature Ideas
 - DSL for declaring Navigation Graphs
 - When presenting a modal, it should automaitcally create a new navigation controller and navigation graph.
 - Rehydrating navigation stack
 - Creating navigation graphs from Codables
 - Deep linking into a certain point in a navigation stack
 - Restore functionality of awaitCompletion(). Each NavNode should be async.
 - Ability to register edges in priority. This may be helpful in ensuring that there will always be a valid flow.
 - Include check to make sure no nodes are repeated
 - When pressing Ok on modal, the navigation controller should actually perform the dismiss, not the VC

 */


// MARK: - Navigation graph

/// A directed graph that defines the navigation structure of an application.
///
/// `NavigationGraph` stores a collection of nodes representing screens or destinations,
/// connected by edges that define how users can navigate between them. The graph uses
/// an adjacency list representation for efficient pathfinding and navigation.
///
/// ## Overview
///
/// Each navigation graph maintains:
/// - A registry of nodes indexed by their unique identifiers
/// - An adjacency map defining outgoing edges from each node
/// - Path-finding algorithms to determine valid navigation routes
///
/// ## Example
///
/// ```swift
/// let graph = NavigationGraph()
///
/// // Add nodes
/// graph.addNode(welcomeNode)
/// graph.addNode(profileNode)
/// graph.addNode(settingsNode)
///
/// // Define navigation edges
/// graph.addEdge(Edge(
///     from: welcomeNode,
///     to: profileNode,
///     transition: .push,
///     transform: { _ in User(name: "Default") }
/// ))
/// ```
///
/// ## Subgraph Support
///
/// Navigation graphs support nested flows through subgraphs. A subgraph appears
/// as a single node in the parent graph but contains its own internal navigation structure.
///
/// ## Thread Safety
///
/// NavigationGraph is not thread-safe. All operations should be performed on the main queue.
public final class NavigationGraph {

    /// A dictionary mapping node identifiers to their erased node wrappers.
    ///
    /// Each entry must be unique within the graph.
    var nodes: [String: AnyNavNode] = [:]

    /// An adjacency map from node identifiers to their outgoing edges.
    ///
    /// This representation enables efficient lookup of possible transitions
    /// from any given node.
    var adjacency: [String: [AnyNavEdge]] = [:]

    /// Creates a new, empty navigation graph.
    public init() {}

    // MARK: - Node registration

    /// Adds a node to the graph.
    ///
    /// If a node with the same identifier already exists, this method will replace it
    /// in debug builds and crash with a fatal error.
    ///
    /// - Parameter node: The node to add to the graph
    /// - Returns: The graph instance for method chaining
    ///
    /// ## Example
    ///
    /// ```swift
    /// graph.addNode(WelcomeNode())
    ///      .addNode(ProfileNode())
    ///      .addNode(SettingsNode())
    /// ```
    @discardableResult
    public func addNode<N: NavNode>(_ node: N) -> Self {
        #if DEBUG
        if nodes[node.id] != nil {
            fatalError("Node \(node.id) already exists in this graph \(N.self). Check your registrations.")
        }
        #endif
        let wrapped = AnyNavNode(node)
        nodes[node.id] = wrapped
        if adjacency[node.id] == nil {
            adjacency[node.id] = []
        }
        return self
    }

    /// Adds a subgraph as a node in this graph.
    ///
    /// The subgraph appears as a single node whose `InputType` and `OutputType`
    /// match those of its start node. Once added, you can connect edges to and from
    /// the subgraph like any other node.
    ///
    /// - Parameter subgraph: The subgraph to add
    /// - Returns: The graph instance for method chaining
    ///
    /// ## Navigation Within Subgraphs
    ///
    /// To navigate within the subgraph, call `findPath` on the subgraph's
    /// internal `NavigationGraph`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let signInSubgraph = NavSubgraph(
    ///     id: "signIn",
    ///     graph: signInGraph,
    ///     start: signInHomeNode
    /// )
    /// graph.addSubgraph(signInSubgraph)
    /// ```
    @discardableResult
    public func addSubgraph<Entry: NavNode, Exit: NavNode>(_ subgraph: NavSubgraph<Entry, Exit>) -> Self {
        let wrapped = AnyNavNode(subgraph)
        nodes[subgraph.id] = wrapped
        if adjacency[subgraph.id] == nil {
            adjacency[subgraph.id] = []
        }
        return self
    }

    // MARK: - Edge registration

    /// Adds a directed edge to the graph.
    ///
    /// Edges define how users can navigate between nodes, including the transition
    /// type and any data transformation required.
    ///
    /// - Parameter edge: The edge to add
    /// - Returns: The graph instance for method chaining
    /// - Precondition: Both the source and destination nodes must already be registered in the graph
    ///
    /// ## Example
    ///
    /// ```swift
    /// graph.addEdge(Edge(
    ///     from: welcomeNode,
    ///     to: profileNode,
    ///     transition: .push,
    ///     predicate: { $0 == .viewProfile },
    ///     transform: { _ in currentUser }
    /// ))
    /// ```
    @discardableResult
    public func addEdge<From: NavNode, To: NavNode>(_ edge: Edge<From, To>) -> Self {
        guard let fromWrapped = nodes[edge.from.id] else {
            fatalError("From Node `\(edge.from.id)` doesn't exist in graph `\(self)`")
        }

        guard let toWrapped = nodes[edge.to.id] else {
            fatalError("To Node `\(edge.to.id)` doesn't exist in graph `\(self)`")
        }

        let list = adjacency[edge.from.id] ?? []
        let anyEdge = AnyNavEdge(edge, from: fromWrapped, to: toWrapped)
        adjacency[edge.from.id] = list + [anyEdge]
        return self
    }

    // MARK: Reachability and path finding

    /// Determines whether a navigation path exists between two nodes.
    ///
    /// - Parameters:
    ///   - sourceId: The identifier of the starting node
    ///   - destinationId: The identifier of the target node
    /// - Returns: `true` if a path exists, `false` otherwise
    ///
    /// ## Complexity
    ///
    /// This method uses breadth-first search, so the time complexity is O(V + E)
    /// where V is the number of nodes and E is the number of edges.
    public func canNavigate(from sourceId: String, to destinationId: String) -> Bool {
        return findPath(from: sourceId, to: destinationId) != nil
    }

    /// Determines whether a navigation path exists between two nodes.
    ///
    /// This is a convenience overload that accepts node instances directly.
    ///
    /// - Parameters:
    ///   - source: The starting node
    ///   - destination: The target node
    /// - Returns: `true` if a path exists, `false` otherwise
    public func canNavigate<From: NavNode, To: NavNode>(from source: From, to destination: To) -> Bool {
        return canNavigate(from: source.id, to: destination.id)
    }

    /// Finds a navigation path between two nodes using breadth-first search.
    ///
    /// - Parameters:
    ///   - sourceId: The identifier of the starting node
    ///   - destinationId: The identifier of the target node
    /// - Returns: An array of edges representing the path, or `nil` if no path exists
    ///
    /// ## Algorithm
    ///
    /// Uses breadth-first search to find the shortest path in terms of number of hops.
    /// The algorithm guarantees finding the shortest path if one exists.
    ///
    /// - Todo: Add subgraph support for pathfinding across nested graphs
    func findPath(from sourceId: String, to destinationId: String) -> [AnyNavEdge]? {
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

    /// Finds a navigation path between two nodes.
    ///
    /// This is a convenience overload that accepts node instances directly.
    ///
    /// - Parameters:
    ///   - source: The starting node
    ///   - destination: The target node
    /// - Returns: An array of edges representing the path, or `nil` if no path exists
    func findPath<From: NavNode, To: NavNode>(from source: From, to destination: To) -> [AnyNavEdge]? {
        return findPath(from: source.id, to: destination.id)
    }
    
    // MARK: - Graph Helpers
    
    /// Checks whether a specific node is registered in this graph.
    ///
    /// - Parameter node: The node to check for
    /// - Returns: `true` if the node exists in the graph, `false` otherwise
    func hasNode<Node: NavNode>(_ node: Node) -> Bool {
        return nodes.contains(where: { $0.key == node.id })
    }

    // MARK: - Pretty printing

    /// Returns a human-readable description of a navigation path.
    ///
    /// Each edge is formatted as `fromId --(transition)--> toId`.
    ///
    /// - Parameter path: The path to format
    /// - Returns: A string representation of the path, or empty string if the path is empty
    ///
    /// ## Example Output
    ///
    /// ```
    /// welcome --(push)--> profile
    /// profile --(modal)--> settings
    /// settings --(dismiss)--> profile
    /// ```
    func prettyPrintPath(_ path: [AnyNavEdge]) -> String {
        guard !path.isEmpty else { return "" }
        return path.map { edge in
            "\(edge.fromNode.id) --(\(edge.transition))--> \(edge.toNode.id)"
        }.joined(separator: "\n")
    }
}

#if DEBUG
// MARK: - Testability Helpers and Graph Validation

/// Represents a single step in a navigation dry run.
///
/// A navigation step captures the transition from one node to another,
/// including the data flow and transition type used.
public struct NavigationStep {
    /// The identifier of the source node.
    public let from: String
    
    /// The identifier of the destination node.
    public let to: String
    
    /// The transition type used for this navigation step.
    public let transition: TransitionType
    
    /// The output data from the source node.
    public let output: Any
    
    /// The input data provided to the destination node.
    public let input: Any
}

public extension NavigationGraph {
    /// Errors that can occur during graph operations.
    enum GraphError: Error {
        /// A general error with a descriptive message.
        case error(message: String)
    }
}

public extension NavigationGraph {
    /// Simulates navigation through the graph without presenting UI.
    ///
    /// This method is invaluable for testing navigation flows, validating graph
    /// structure, and debugging complex navigation scenarios.
    ///
    /// - Parameters:
    ///   - startId: The identifier of the starting node
    ///   - initialInput: The initial input data for the start node
    ///   - outputProvider: A closure that provides output data for each node
    ///   - stopAt: An optional predicate to stop simulation at specific nodes
    ///   - maxHops: Maximum number of navigation steps to prevent infinite loops
    /// - Returns: An array of navigation steps taken during the simulation
    /// - Throws: `GraphError.error` if navigation gets stuck or exceeds maximum hops
    ///
    /// ## Example
    ///
    /// ```swift
    /// let steps = try graph.dryRun(
    ///     from: "welcome",
    ///     initialInput: (),
    ///     outputProvider: { nodeId, input in
    ///         switch nodeId {
    ///         case "profile": return ProfileResult.save
    ///         case "settings": return SettingsResult.done
    ///         default: return ()
    ///         }
    ///     },
    ///     stopAt: { $0 == "end" }
    /// )
    /// ```
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

    /// Validates that a path exists between two nodes with expected transitions.
    ///
    /// This method is useful for testing that specific navigation flows are properly
    /// configured in your graph.
    ///
    /// - Parameters:
    ///   - startId: The identifier of the starting node
    ///   - endId: The identifier of the ending node
    ///   - expectedTransitions: Optional array of expected transition types
    /// - Returns: An array of node identifiers in the path
    /// - Throws: `GraphError.error` if no path exists or transitions don't match expectations
    ///
    /// ## Example
    ///
    /// ```swift
    /// let path = try graph.assertPath(
    ///     from: "welcome",
    ///     to: "settings",
    ///     expectedTransitions: [.push, .modal]
    /// )
    /// ```
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

    /// Identifies nodes that cannot be reached from any other node.
    ///
    /// Unreachable nodes might indicate configuration errors in your navigation graph.
    ///
    /// - Returns: A set of node identifiers that are unreachable
    ///
    /// ## Example
    ///
    /// ```swift
    /// let unreachable = graph.unreachableNodes()
    /// if !unreachable.isEmpty {
    ///     print("Warning: Unreachable nodes found: \(unreachable)")
    /// }
    /// ```
    func unreachableNodes() -> Set<String> {
        var reachable = Set<String>()
        for (_, edges) in adjacency {
            for edge in edges {
                reachable.insert(edge.toNode.id)
            }
        }
        return Set(nodes.keys).subtracting(reachable)
    }

    /// Detects whether the graph contains any cycles.
    ///
    /// Cycles in navigation graphs may or may not be desirable, depending on your
    /// application's requirements. This method helps identify them for analysis.
    ///
    /// - Returns: `true` if the graph contains at least one cycle, `false` otherwise
    ///
    /// ## Algorithm
    ///
    /// Uses depth-first search with a recursion stack to detect back edges,
    /// which indicate the presence of cycles.
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

    /// Validates edge type compatibility across the graph.
    ///
    /// This is a placeholder for future type validation functionality.
    /// Currently returns an empty array due to Swift's type erasure limitations with `Any`.
    ///
    /// - Returns: An array of validation error messages
    /// - Note: This method is not fully implemented due to runtime type information limitations
    func validateEdgeTypes() -> [String] {
        // Not implemented due to Swift's type erasure with Any—could expand with custom test values or code generation.
        return []
    }
}

extension NavigationGraph {
    /// Generates a visual representation of the graph structure.
    ///
    /// This method creates a tree-like outline showing the navigation structure,
    /// including subgraphs and their internal organization.
    ///
    /// - Parameter rootId: The identifier of the node to use as the root of the outline
    /// - Returns: A formatted string showing the graph structure
    ///
    /// ## Example Output
    ///
    /// ```
    /// └─ welcome
    ///    ├─ signInSubgraph
    ///    │  ┌─ [Subgraph: signInSubgraph]
    ///    │  │  ├─ SignInHomeNode
    ///    │  │  │  └─ ForgotPasswordNode
    ///    │  │  └──────────────
    ///    └─ profile
    ///       └─ settings
    /// ```
    public func prettyPrintOutline(from rootId: String) -> String {
        guard nodes[rootId] != nil else { return "Root node \(rootId) not found." }

        var output: [String] = []
        var visited: Set<String> = []

        func dfs(_ nodeId: String, prefix: String, isLast: Bool) {
            let marker = isLast ? "└─ " : "├─ "
            output.append("\(prefix)\(marker)\(nodeId)")
            visited.insert(nodeId)

            // Check if node is a subgraph and include its internal graph
            if let subgraphNode = nodes[nodeId]?.wrappedNode as? NavSubgraphProtocol {
                let subPrefix = prefix + (isLast ? "   " : "│  ")
                output.append("\(subPrefix)┌─ [Subgraph: \(subgraphNode.id)]")
                let subgraphOutline = subgraphNode.graph.prettyPrintOutline(from: subgraphNode.entryNodeId)
                let indented = subgraphOutline
                    .split(separator: "\n")
                    .map { "\(subPrefix)│  \($0)" }
                output.append(contentsOf: indented)
                output.append("\(subPrefix)└──────────────")
            }

            // Traverse children from adjacency map
            let children = adjacency[nodeId] ?? []
            let nextPrefix = prefix + (isLast ? "   " : "│  ")

            for (index, edge) in children.enumerated() {
                let isChildLast = index == children.count - 1
                let toId = edge.toNode.id

                if !visited.contains(toId) {
                    dfs(toId, prefix: nextPrefix, isLast: isChildLast)
                } else {
                    let loopMarker = isChildLast ? "└─ " : "├─ "
                    output.append("\(nextPrefix)\(loopMarker)[loop] \(toId)")
                }
            }
        }

        dfs(rootId, prefix: "", isLast: true)
        return output.joined(separator: "\n")
    }
}
#endif
