import Foundation

/// A registry for navigation nodes and subgraphs that provides type-safe registration and lookup.
///
/// `NodeRegistry` serves as a dependency injection container for navigation nodes, enabling
/// centralized management of node instances and supporting shared nodes across multiple graphs.
/// It provides type-safe registration and resolution while maintaining efficient lookup performance.
///
/// ## Overview
///
/// The registry enables:
/// - **Centralized node management**: Single source of truth for node instances
/// - **Type-safe resolution**: Compile-time guarantees for node types
/// - **Shared nodes**: Reuse node instances across multiple navigation graphs
/// - **Subgraph support**: Registration and resolution of nested navigation flows
///
/// ## Usage Patterns
///
/// ### Basic Registration and Resolution
/// ```swift
/// let registry = NodeRegistry()
/// registry.register(WelcomeNode())
/// registry.register(ProfileNode())
/// 
/// let welcomeNode = registry.resolve(WelcomeNode.self)
/// let profileNode = registry.resolve(ProfileNode.self)
/// ```
///
/// ### Graph Construction
/// ```swift
/// let graph = NavigationGraph()
/// graph.addNode(registry.resolve(WelcomeNode.self))
/// graph.addNode(registry.resolve(ProfileNode.self))
/// ```
///
/// ## Thread Safety
///
/// NodeRegistry is not thread-safe. All registration and resolution operations
/// should be performed on the same queue, typically during application setup.
public final class NodeRegistry {
    /// Internal storage mapping type identifiers to node instances.
    ///
    /// Uses `ObjectIdentifier` for efficient type-based lookup while maintaining
    /// type safety through the public API.
    private var storage: [ObjectIdentifier: AnyNavNode] = [:]

    /// Creates a new, empty node registry.
    ///
    /// ## Example
    /// ```swift
    /// let registry = NodeRegistry()
    /// ```
    public init() {}

    /// Checks whether a node of the specified type is registered.
    ///
    /// - Parameter node: A node instance to check for registration
    /// - Returns: `true` if a node of this type is registered, `false` otherwise
    ///
    /// ## Example
    /// ```swift
    /// let welcomeNode = WelcomeNode()
    /// registry.register(welcomeNode)
    /// 
    /// let hasNode = registry.hasNode(WelcomeNode()) // true
    /// let hasOther = registry.hasNode(ProfileNode()) // false
    /// ```
    ///
    /// ## Performance
    /// This operation is O(1) based on type identity lookup.
    public func hasNode<N: NavNode>(_ node: N) -> Bool {
        let storageId = ObjectIdentifier(type(of: node))
        return storage[storageId] != nil
    }

    /// Registers a navigation node in the registry.
    ///
    /// If a node of the same type is already registered, it will be replaced
    /// with the new instance. Registration is based on the concrete type,
    /// not the instance identity.
    ///
    /// - Parameter node: The navigation node to register
    ///
    /// ## Type-Based Registration
    /// 
    /// The registry uses the concrete type of the node as the key, meaning
    /// only one instance of each node type can be registered at a time.
    ///
    /// ## Example
    /// ```swift
    /// registry.register(WelcomeNode())
    /// registry.register(ProfileNode())
    /// registry.register(SettingsNode())
    /// 
    /// // Replacing an existing registration
    /// let newWelcome = WelcomeNode()
    /// registry.register(newWelcome) // Replaces the previous WelcomeNode
    /// ```
    ///
    /// ## Performance
    /// Registration is O(1) for type-based storage operations.
    public func register<N: NavNode>(_ node: N) {
        storage[ObjectIdentifier(type(of: node))] = AnyNavNode(node)
    }

    /// Registers a subgraph that conforms to `NavSubgraphProtocol`.
    ///
    /// Subgraphs are registered using the same type-based system as regular nodes,
    /// enabling them to be resolved and used in navigation graphs.
    ///
    /// - Parameter subgraph: The subgraph to register
    ///
    /// ## Example
    /// ```swift
    /// let exitNode = HeadlessNode<Void, Void>()
    /// let signInSubgraph = NavSubgraph(
    ///     id: "signIn",
    ///     graph: signInGraph,
    ///     entry: signInHomeNode,
    ///     exit: exitNode
    /// )
    /// registry.registerSubgraph(signInSubgraph)
    /// ```
    ///
    /// ## Replacement Behavior
    /// If a subgraph of the same type is already registered, it will be replaced
    /// with the new instance, similar to regular node registration.
    public func registerSubgraph<N: NavNode>(_ subgraph: N) {
        storage[ObjectIdentifier(type(of: subgraph))] = AnyNavNode(subgraph)
    }

    /// Resolves a node instance by its concrete type.
    ///
    /// - Parameter type: The type of node to resolve
    /// - Returns: The registered node instance of the specified type
    /// - Precondition: A node of the specified type must be registered
    ///
    /// ## Type Safety
    /// 
    /// The return type is guaranteed to match the requested type, providing
    /// compile-time type safety for node resolution.
    ///
    /// ## Example
    /// ```swift
    /// let welcomeNode = registry.resolve(WelcomeNode.self)
    /// let profileNode = registry.resolve(ProfileNode.self)
    /// 
    /// // Use in graph construction
    /// graph.addNode(registry.resolve(WelcomeNode.self))
    /// ```
    ///
    /// ## Fatal Error Conditions
    /// 
    /// This method will crash with a fatal error if:
    /// - No node of the specified type is registered
    /// - The registered node cannot be cast to the expected type (internal error)
    ///
    /// ## Performance
    /// Resolution is O(1) based on type identity lookup.
    public func resolve<N: NavNode>(_ type: N.Type) -> N {
        guard let resolved = storage[ObjectIdentifier(type)] else {
            fatalError("Node `\(type)` isn't registered")
        }
        return (resolved.wrappedNode as! N)
    }

    /// Resolves a subgraph by its concrete type.
    ///
    /// - Parameter type: The type of subgraph to resolve
    /// - Returns: The registered subgraph instance, or `nil` if not found
    ///
    /// ## Optional Return
    /// 
    /// Unlike regular node resolution, subgraph resolution returns an optional
    /// to handle cases where the subgraph might not be registered.
    ///
    /// ## Example
    /// ```swift
    /// if let signInSubgraph = registry.resolveSubgraph(SignInSubgraph.self) {
    ///     mainGraph.addSubgraph(signInSubgraph)
    /// }
    /// ```
    ///
    /// ## Type Constraints
    /// 
    /// The type must conform to `NavSubgraphProtocol` to be resolvable as a subgraph.
    public func resolveSubgraph<T: NavSubgraphProtocol>(_ type: T.Type) -> T? {
        return (storage[ObjectIdentifier(type)]?.wrappedNode as? T)
    }

    /// Returns all registered nodes and subgraphs as type-erased instances.
    ///
    /// This property provides access to the complete collection of registered
    /// nodes for bulk operations or graph ingestion scenarios.
    ///
    /// ## Use Cases
    /// 
    /// - Mass registration in navigation graphs
    /// - Diagnostic operations on the registry contents
    /// - Migration or export scenarios
    ///
    /// ## Example
    /// ```swift
    /// // Register all nodes in a graph at once
    /// for node in registry.allNodes {
    ///     graph.addNode(node)
    /// }
    /// ```
    ///
    /// ## Performance
    /// 
    /// Returns a new array containing all registered nodes. The complexity
    /// is O(n) where n is the number of registered nodes.
    var allNodes: [AnyNavNode] {
        Array(storage.values)
    }
}
