//
//  NavNode.swift
//  NavigationGraph
//
//  Created by mexicanpizza on 7/29/25.
//

/// A protocol representing a node within the navigation graph.
///
/// Each node in a navigation graph represents a destination or screen in your application's flow.
/// Nodes are connected by edges that define how users can navigate between them.
///
/// ## Overview
///
/// A `NavNode` defines two important associated types:
/// - `InputType`: The data required to present this destination
/// - `OutputType`: The data produced when the user completes interaction with this screen
///
/// For screens that don't require input or produce output, use `Void` for these types.
///
/// ## Example
///
/// ```swift
/// final class WelcomeNode: NavNode {
///     typealias InputType = Void
///     typealias OutputType = WelcomeResult
///     
///     enum WelcomeResult {
///         case next
///         case signIn
///     }
/// }
/// ```
///
/// ## Identity
///
/// Each node must provide a unique identifier via the `id` property. Two nodes with the same
/// identifier are considered identical within a single navigation graph.
///
/// - Note: The default implementation generates an ID based on the class name.
public protocol NavNode: AnyObject {
    /// The type of data required to instantiate or present this destination.
    ///
    /// Use `Void` if the screen requires no input data.
    associatedtype InputType
    
    /// The type of data produced by this node upon completion.
    ///
    /// Use `Void` if the screen produces no output data.
    associatedtype OutputType
    
    /// A unique identifier for the node.
    ///
    /// Two nodes with the same identifier are considered identical within the context of a
    /// single navigation graph.
    var id: String { get }
}

/// A type-erased wrapper for `NavNode` instances.
///
/// `AnyNavNode` enables storing nodes with different generic types in the same collection.
/// It preserves the node's identity and provides access to subgraph information when applicable.
///
/// ## Overview
///
/// The navigation graph uses `AnyNavNode` internally to store heterogeneous node types
/// in a single adjacency map. This type erasure is essential for the graph's flexibility
/// while maintaining type safety at the edge level.
///
/// ## Subgraph Support
///
/// If a node represents a nested subgraph, the `subgraphWrapper` property provides
/// access to the internal graph structure without requiring type casting.
public final class AnyNavNode {

    /// The node's unique identifier.
    let id: String
    
    /// The wrapped node instance.
    ///
    /// This property preserves the original node for identity comparison.
    /// - Warning: Do not use this property directly. Use the type-safe APIs instead.
    let wrappedNode: Any

    /// Information about the subgraph if this node represents one.
    ///
    /// This property is `nil` for regular screen nodes and contains subgraph
    /// details for nodes that represent nested navigation flows.
    public let subgraphWrapper: SubgraphWrapper?

    /// Essential properties of a subgraph for runtime navigation.
    ///
    /// This wrapper captures the information needed to navigate within a subgraph
    /// without exposing generic type parameters.
    public struct SubgraphWrapper {

        /// The identifier of the subgraph.
        public let id: String

        /// The nested navigation graph representing the flow inside the subgraph.
        public let graph: NavigationGraph

        /// The identifier of the start node within `graph`.
        public let entryNodeId: String

        /// The identifier of the start node within `graph`.
        public let exitNodeId: String
    }

    /// Creates a type-erased wrapper for a navigation node.
    ///
    /// - Parameter node: The node to wrap
    public init<Node: NavNode>(_ node: Node) {
        self.id = node.id
        self.wrappedNode = node

        // Determine if this node is a nested subgraph.  We use the
        // `NavSubgraphProtocol` protocol to abstract over the generic
        // type of the subgraph.  If the node conforms to this
        // protocol, capture its internal graph and start node id in
        // `subgraphWrapper`.  Otherwise leave it nil.
        if let sub = node as? NavSubgraphProtocol {
            self.subgraphWrapper = SubgraphWrapper(
                id: sub.id,
                graph: sub.graph,
                entryNodeId: sub.entryNodeId,
                exitNodeId: sub.exitNodeId
            )
        } else {
            self.subgraphWrapper = nil
        }
    }
}

extension AnyNavNode {
    /// Returns a type-erased view controller factory for this node.
    ///
    /// - Returns: A view controller factory that can create instances for this node, or `nil` if unsupported
    var anyViewControllerProviding: AnyViewControllerProviding? {
        guard let viewControllerProviding = wrappedNode as? (any ViewControllerProviding) else {
            return nil
        }
        return AnyViewControllerProviding(viewControllerProviding)
    }
}

extension AnyNavNode {

    /// Returns a fully qualified identifier describing this node's position within nested subgraphs.
    ///
    /// The format follows the pattern: `[subgraphId1].[subgraphId2].<nodeId>`
    ///
    /// ## Example
    ///
    /// For a node inside nested subgraphs:
    /// ```
    /// "authFlow.signIn.forgotPassword"
    /// ```
    ///
    /// For a root-level node:
    /// ```
    /// "welcome"
    /// ```
    public var fullyQualifiedId: String {
        func buildId(from node: AnyNavNode?) -> String {
            guard let subgraph = node?.subgraphWrapper else {
                return ""
            }
            
            // Recurse upward if the subgraph itself is wrapped in another subgraph node (linked by its graph's root node)
            // Assume the subgraph's graph contains a start node with its own AnyNavNode representation
            let rootNode = subgraph.graph.nodes[subgraph.entryNodeId]
            let parentId = buildId(from: rootNode)
            return parentId.isEmpty ? subgraph.id : parentId + "." + subgraph.id
        }
        let prefix = buildId(from: self)
        return prefix.isEmpty ? id : prefix + "." + id
    }
}

extension AnyNavNode {
    /// Returns the type-erased headless processor if this node is a `HeadlessNode`.
    var anyHeadlessProcessor: AnyHeadlessTransforming? {
        return wrappedNode as? AnyHeadlessTransforming
    }
}

extension NavNode {
    /// Default implementation that generates an ID based on the type name.
    ///
    /// This provides a reasonable default for most use cases, but you can override
    /// this property to provide custom identifiers when needed.
    var id: String {
        "\(Self.self)"
    }
}
