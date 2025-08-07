import Foundation

/// A registry for navigation nodes and subgraphs, allowing type-safe registration and lookup.
/// Nodes and subgraphs can be registered globally, shared across graphs, or composed into subgraphs.
public final class NodeRegistry {
    private var storage: [ObjectIdentifier: AnyNavNode] = [:]

    public init() {}

    public func hasNode<N: NavNode>(_ node: N) -> Bool {
        let storageId = ObjectIdentifier(type(of: node))
        return storage[storageId] != nil
    }

    /// Register a node by its concrete type. If a node of the same type is already registered, it is replaced.
    public func register<N: NavNode>(_ node: N) {
        storage[ObjectIdentifier(type(of: node))] = AnyNavNode(node)
    }

    /// Register a subgraph that conforms to NavSubgraphProtocol. If a subgraph of the same type is already registered, it is replaced.
    public func registerSubgraph<N: NavNode>(_ subgraph: N) {
        storage[ObjectIdentifier(type(of: subgraph))] = AnyNavNode(subgraph)
    }

    /// Resolve a node instance by its concrete type. Returns nil if not found.
    public func resolve<N: NavNode>(_ type: N.Type) -> N {
        guard let resolved = storage[ObjectIdentifier(type)] else {
            fatalError("Node `\(type)` isn't registered")
        }
        return (resolved.wrappedNode as! N)
    }

    /// Resolve a subgraph by its concrete type conforming to NavSubgraphProtocol. Returns nil if not found.
    public func resolveSubgraph<T: NavSubgraphProtocol>(_ type: T.Type) -> T? {
        return (storage[ObjectIdentifier(type)]?.wrappedNode as? T)
    }

    /// Returns all registered nodes and subgraphs as an array of AnyNavNode (for graph ingestion).
    var allNodes: [AnyNavNode] {
        Array(storage.values)
    }
}
