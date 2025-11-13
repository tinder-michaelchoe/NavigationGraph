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
/// The subgraph's `InputType` is determined by its entry node, and `OutputType` is
/// determined by its exit node. When navigation enters the subgraph, it begins at
/// the entry node. When navigation reaches the exit node, control returns to the
/// parent graph.
///
/// ## Example
///
/// ```swift
/// let signInFlow = NavigationGraph()
/// let exitNode = HeadlessNode<Void, Void>()
///
/// signInFlow.addNode(signInHome)
/// signInFlow.addNode(forgotPassword)
/// signInFlow.addNode(exitNode)
///
/// signInFlow.addEdge(Edge(from: signInHome, to: forgotPassword, transition: .push))
/// signInFlow.addEdge(Edge(from: forgotPassword, to: exitNode, transition: .none))
///
/// let signInSubgraph = NavSubgraph(
///     id: "signInFlow",
///     graph: signInFlow,
///     entry: signInHome,
///     exit: exitNode
/// )
///
/// // Add to main graph
/// mainGraph.addSubgraph(signInSubgraph)
/// ```
///
/// ## Exit Nodes
///
/// Exit nodes are typically headless nodes that complete without presenting UI.
/// They signal the completion of the subgraph flow and return control to the parent graph.
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

    /// Creates a new navigation subgraph with explicit entry and exit nodes.
    ///
    /// - Parameters:
    ///   - id: A unique identifier for the subgraph
    ///   - graph: The internal navigation graph
    ///   - entry: The entry node where navigation begins within the subgraph
    ///   - exit: The exit node where navigation completes within the subgraph
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
