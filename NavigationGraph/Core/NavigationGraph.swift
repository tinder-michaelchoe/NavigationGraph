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

/// A `NavigationGraph` stores a collection of nodes and the edges connecting them.
public final class NavigationGraph {

    /// A dictionary mapping node identifiers to their erased node wrappers.  Each entry must be unique.
    var nodes: [String: AnyNavNode] = [:]

    /// An adjacency map from node identifiers to their outgoing edges.
    var adjacency: [String: [AnyNavEdge]] = [:]

    public init() {}

    // MARK: - Node registration

    /// Adds a node to the graph.  If a node with the same id already exists, this method will replace it.
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

    /// Adds a subgraph as a node in this graph.  The subgraph is
    /// represented as a single node whose `DataType` matches the
    /// `DataType` of its start node. Once added, you can connect
    /// edges to and from the subgraph just like any other node. To
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

    // MARK: - Edge registration

    /// Adds a directed edge to the graph.
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

    /// Returns a boolean indicating whether a path exists between the
    /// specified source id and destination id nodes.
    public func canNavigate(from sourceId: String, to destinationId: String) -> Bool {
        return findPath(from: sourceId, to: destinationId) != nil
    }

    /// Generic overload that accepts node instances directly.
    public func canNavigate<From: NavNode, To: NavNode>(from source: From, to destination: To) -> Bool {
        return canNavigate(from: source.id, to: destination.id)
    }

    /// Finds a path from the node with id `sourceId` to the node
    /// `destinationId` using breadth‑first search.
    ///
    /// TODO [Michael] Add subgraph support
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

    /// Generic overload of `findPath` that accepts node instances directly.
    func findPath<From: NavNode, To: NavNode>(from source: From, to destination: To) -> [AnyNavEdge]? {
        return findPath(from: source.id, to: destination.id)
    }
    
    // MARK: - Graph Helpers
    
    func hasNode<Node: NavNode>(_ node: Node) -> Bool {
        return nodes.contains(where: { $0.key == node.id })
    }

    // MARK: - Pretty printing

    /// Returns a human‑readable description of the provided path.  Each
    /// edge is formatted as `fromId --(transition)--> toId`.  If the
    /// path is empty, an empty string is returned.
    func prettyPrintPath(_ path: [AnyNavEdge]) -> String {
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
///
/// TODO [Michael] Make the OutputType more flexible, i.e. not just the start node
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

    public init(id: String, graph: NavigationGraph, start: Start) {
        self.id = id
        self.graph = graph
        self.startNodeId = start.id
    }
}

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

extension NavigationGraph {
    /// Pretty-prints the graph starting from the given node, including subgraphs.
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
                let subgraphOutline = subgraphNode.graph.prettyPrintOutline(from: subgraphNode.startNodeId)
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
