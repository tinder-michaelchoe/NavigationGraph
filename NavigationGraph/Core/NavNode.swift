//
//  NavNode.swift
//  NavigationGraph
//
//  Created by mexicanpizza on 7/29/25.
//

/// A protocol representing a node within the navigation graph.  Each
/// node has an associated `InputType` which describes the type of
/// information passed into that screen when it is navigated to, and
/// an associated `OutputType` which describes the type of data that
/// the node produces when it completes.  For screens that do not require
/// input or produce output, use `Void` for these associated types.
/// Conforming types must provide a unique `id` that identifies them
/// within the graph.
public protocol NavNode {
    /// The type of data required to instantiate or present this
    /// destination.  This is analogous to the `@Serializable` route
    /// classes used in Android's Navigation component.  Using an
    /// associated type enforces that only data of this type can be
    /// passed to the node.
    associatedtype InputType
    
    /// The type of data produced by this node upon completion.  This
    /// allows downstream nodes to accept output from this node as input.
    associatedtype OutputType
    
    /// A unique identifier for the node.  Two nodes with the same
    /// identifier are considered identical within the context of a
    /// single navigation graph.
    var id: String { get }
}

/// An internal class used to erase the generic type of a `NavNode` so
/// that nodes of heterogeneous data types can be stored together in
/// collections.  Instances of `AnyNavNode` wrap a concrete node and
/// expose only the minimal information needed by the graph: the node's
/// identifier and the runtime type of its associated input and output data.
/// It also stores type‑checking closures used to validate data passed to
/// transformation functions.
public final class AnyNavNode {
    /// The node's unique identifier.
    let id: String
    
    /// The wrapped node.  This is stored to preserve identity when
    /// comparing nodes.  We do not expose it publicly to avoid
    /// leaking the associated type. Do not use this directly.
    let wrappedNode: Any

    /// If this node represents a nested subgraph, this wrapper holds
    /// the internal graph and the identifier of its start node.  It is
    /// `nil` for regular screens.  Storing this directly on the node
    /// avoids the need for type casting at runtime when determining
    /// whether a node is a subgraph.
    public let subgraphWrapper: SubgraphWrapper?

    /// A simple wrapper used to capture the essential properties of a
    /// subgraph for runtime navigation.  It stores the nested graph
    /// itself and the id of its start node.  See `NavSubgraph`
    /// below for details.
    public struct SubgraphWrapper {
        /// The identifier of the subgraph.  This is the same value
        /// returned by the underlying `NavSubgraph`'s `id` property.
        public let id: String
        /// The nested navigation graph representing the flow inside
        /// the subgraph.
        public let graph: NavigationGraph
        /// The identifier of the start node within `graph`.  When
        /// navigating into the subgraph, the controller begins with
        /// this node.
        public let startNodeId: String
    }

    /// Wraps a concrete node in an `AnyNavNode`.
    public init<Node: NavNode>(_ node: Node) {
        self.id = node.id
        self.wrappedNode = node

        // Determine if this node is a nested subgraph.  We use the
        // `NavSubgraphProtocol` protocol to abstract over the generic
        // type of the subgraph.  If the node conforms to this
        // protocol, capture its internal graph and start node id in
        // `subgraphWrapper`.  Otherwise leave it nil.
        if let sub = node as? NavSubgraphProtocol {
            self.subgraphWrapper = SubgraphWrapper(id: sub.id, graph: sub.graph, startNodeId: sub.startNodeId)
        } else {
            self.subgraphWrapper = nil
        }
    }
}
