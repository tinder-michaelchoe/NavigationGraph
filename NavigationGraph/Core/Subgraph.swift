//
//  Subgraph.swift
//  NavigationGraph
//
//  Created by Michael Choe on 8/9/25.
//

// MARK: - Subgraphs

/// A navigation subgraph that can be embedded within a parent graph.
///
/// `NavSubgraph` encapsulates a nested navigation flow and conforms to `NavNode`
/// so it can be treated as a single node in a parent graph. This enables building
/// complex, hierarchical navigation structures.
///
/// ## Overview
///
/// The subgraph's `InputType` and `OutputType` are determined by its start node.
/// When navigation enters the subgraph, it begins at the start node. When navigation
/// exits the subgraph (no valid edges found), the parent graph resumes control.
///
/// ## Example
///
/// ```swift
/// let signInFlow = NavigationGraph()
/// signInFlow.addNode(signInHome)
/// signInFlow.addNode(forgotPassword)
/// signInFlow.addEdge(Edge(from: signInHome, to: forgotPassword, transition: .push))
///
/// let signInSubgraph = NavSubgraph(
///     id: "signInFlow",
///     graph: signInFlow,
///     start: signInHome
/// )
///
/// // Add to main graph
/// mainGraph.addSubgraph(signInSubgraph)
/// ```
///
/// - Todo: Make the OutputType more flexible, not just tied to the start node
public final class NavSubgraph<Entry: NavNode, Exit: NavNode>: NavNode {

    public typealias InputType = Entry.InputType
    public typealias OutputType = Exit.OutputType

    /// The unique identifier for the subgraph.
    ///
    /// This identifier must be unique within the parent graph.
    public let id: String

    /// The internal navigation graph containing the nested flow.
    public let graph: NavigationGraph

    /// The identifier of the entry node within the internal graph.
    public let entryNodeId: String

    /// The identifier of the exit node within the internal graph.
    public let exitNodeId: String

    /// Creates a new navigation subgraph.
    ///
    /// - Parameters:
    ///   - id: A unique identifier for the subgraph
    ///   - graph: The internal navigation graph
    ///   - start: The starting node within the internal graph
    public init(id: String, graph: NavigationGraph, entry: Entry, exit: Exit) {
        self.id = id
        self.graph = graph
        self.entryNodeId = entry.id
        self.exitNodeId = exit.id
    }
}

/// A protocol that abstracts over `NavSubgraph` without exposing generic types.
///
/// This protocol enables runtime operations on subgraphs without knowing their
/// concrete `Start` type. `NavSubgraph` conforms to this protocol automatically.
///
/// - Important: Only `NavSubgraph` should conform to this protocol. Client code should not implement it.
public protocol NavSubgraphProtocol {
    /// The identifier of the subgraph.
    var id: String { get }

    /// The nested navigation graph associated with the subgraph.
    var graph: NavigationGraph { get }

    /// The identifier of the entry node within the nested graph.
    /// The identifier of the entry node within the nested graph.
    var entryNodeId: String { get }

    /// The identifier of the exit node within the nested graph.
    var exitNodeId: String { get }
}

extension NavSubgraph: NavSubgraphProtocol {}
