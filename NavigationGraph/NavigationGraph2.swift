/*
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

/// Describes the type of transition used to move from one screen to
/// another.  This enum intentionally mirrors the high‑level concepts
/// present in Android's Navigation component (push/hosted,
/// modal/dialog and pop) but can be extended to include custom
/// transition types specific to your application.
public enum TransitionType: CustomStringConvertible {
    /// A push transition inserts the destination onto the navigation
    /// stack.  In UIKit this typically corresponds to
    /// `UINavigationController.pushViewController(_:animated:)`.
    case push
    /// A modal transition presents the destination modally on top of
    /// the current context.  In UIKit this could be
    /// `present(_:animated:completion:)`.
    case modal
    /// A pop transition removes one or more destinations from the
    /// navigation stack.  This can be used when popping back to a
    /// previous screen.  Note that pop transitions are only valid
    /// when navigating back to an ancestor in the back stack.  They
    /// are included here for completeness but are not required for
    /// forward navigation.
    case pop

    /// A textual representation of the transition, used by the
    /// `prettyPrintPath` method to produce human‑readable output.
    public var description: String {
        switch self {
        case .push: return "push"
        case .modal: return "modal"
        case .pop: return "pop"
        }
    }
}

/// A protocol representing a node within the navigation graph.  Each
/// node has an associated `DataType` which describes the type of
/// information passed into that screen when it is navigated to.  For
/// screens that do not require any data, use `Void` as the
/// `DataType`.  Conforming types must provide a unique `id` that
/// identifies them within the graph.
public protocol NavNode {
    /// The type of data required to instantiate or present this
    /// destination.  This is analogous to the `@Serializable` route
    /// classes used in Android's Navigation component.  Using an
    /// associated type enforces that only data of this type can be
    /// passed to the node.
    associatedtype DataType
    /// A unique identifier for the node.  Two nodes with the same
    /// identifier are considered identical within the context of a
    /// single navigation graph.
    var id: String { get }
}

/// A simple concrete implementation of `NavNode` that can be used
/// directly to represent screens in your application.  Each
/// `ScreenNode` is parameterised by the type of data it accepts when
/// navigated to.  For example, a profile screen that requires a
/// `User` object could be defined as `let profileNode = ScreenNode<User>("profile")`.
public struct ScreenNode<Data>: NavNode {
    public typealias DataType = Data
    public let id: String
    public init(_ id: String) {
        self.id = id
    }
}

/// A directed edge between two nodes in the navigation graph.  An
/// edge encodes the type of transition used to navigate from the
/// source (`from`) to the destination (`to`) and contains a
/// transformation closure that maps the source's data type into the
/// destination's data type.  The closure is responsible for
/// preparing any data required by the destination based on the
/// information available in the source.  For nodes whose
/// `DataType` is `Void`, simply ignore the input parameter and
/// return an instance of the destination's `DataType`.
public struct Edge<From: NavNode, To: NavNode> {
    /// A unique identifier for the edge.  This can be useful when
    /// debugging or when multiple edges exist between the same pair
    /// of nodes.  If you do not care about edge identities you can
    /// leave this value as the default.
    public let id: String
    /// The source node of the edge.
    public let from: From
    /// The destination node of the edge.
    public let to: To
    /// The transition used to navigate between nodes.
    public let transition: TransitionType
    /// A function which transforms the source node's `DataType` into
    /// the destination node's `DataType`.  This enables compile‑time
    /// safety by ensuring that only valid data is passed when
    /// navigating between two specific node types.
    public let transform: (From.DataType) -> To.DataType

    /// Creates a new edge between the specified nodes with the given
    /// transition and data transformation.  The `id` parameter
    /// defaults to a generated string combining the source and
    /// destination identifiers but may be overridden for clarity.
    public init(
        id: String? = nil,
        from: From,
        to: To,
        transition: TransitionType,
        transform: @escaping (From.DataType) -> To.DataType
    ) {
        self.id = id ?? "\(from.id)->\(to.id)"
        self.from = from
        self.to = to
        self.transition = transition
        self.transform = transform
    }
}

// MARK: - Type erasure wrappers

/// An internal class used to erase the generic type of a `NavNode` so
/// that nodes of heterogeneous data types can be stored together in
/// collections.  Instances of `AnyNavNode` wrap a concrete node and
/// expose only the minimal information needed by the graph: the node's
/// identifier and the runtime type of its associated data.  It also
/// stores a type‑checking closure used to validate data passed to
/// transformation functions.
internal final class AnyNavNode {
    /// The node's unique identifier.
    let id: String
    /// The metatype of the associated data.
    let dataType: Any.Type
    /// A closure that verifies whether a given value is of the
    /// correct `DataType`.  Returns the typed value on success or nil
    /// otherwise.
    private let typeChecker: (Any) -> Any?
    /// The wrapped node.  This is stored to preserve identity when
    /// comparing nodes.  We do not expose it publicly to avoid
    /// leaking the associated type.
    private let _node: Any

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
    init<N: NavNode>(_ node: N) {
        self.id = node.id
        self.dataType = N.DataType.self
        self._node = node
        self.typeChecker = { value in
            return value as? N.DataType
        }
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

    /// Attempts to cast the provided `Any` value into this node's
    /// `DataType`.  Returns the typed value on success or nil on
    /// failure.
    func cast<Data>(_ value: Any, to _: Data.Type) -> Data? {
        return typeChecker(value) as? Data
    }
}

/// An internal class used to erase the generic types of an `Edge` so
/// that edges of heterogeneous source and destination types can be
/// stored together.  `AnyNavEdge` stores the nodes it connects, the
/// transition type and a type‑checked transformation closure which
/// converts arbitrary data into arbitrary data.  It will crash at
/// runtime if the incoming data type does not match the source node's
/// `DataType`.  This is by design: edge registration always performs
/// compile‑time checks on the closure types, and runtime checks here
/// guard against misconfiguration or misuse.
internal final class AnyNavEdge {
    /// The source node of the edge.
    let fromNode: AnyNavNode
    /// The destination node of the edge.
    let toNode: AnyNavNode
    /// The transition used to navigate between nodes.
    let transition: TransitionType
    /// A unique identifier for the edge.
    let id: String
    /// A transformation closure which accepts and returns values of
    /// type `Any`.  The closure performs runtime type checking and
    /// will `fatalError` if called with the wrong source data type.
    private let transformAny: (Any) -> Any

    /// Creates an erased edge from a concrete `Edge`.  You must
    /// provide the corresponding `AnyNavNode` instances for the
    /// source and destination.  An assertion is thrown if the
    /// provided nodes do not match the types of the edge.
    init<From: NavNode, To: NavNode>(
        _ edge: Edge<From, To>,
        from fromNode: AnyNavNode,
        to toNode: AnyNavNode
    ) {
        precondition(fromNode.id == edge.from.id,
                     "Mismatched 'from' node when creating AnyNavEdge")
        precondition(toNode.id == edge.to.id,
                     "Mismatched 'to' node when creating AnyNavEdge")
        self.fromNode = fromNode
        self.toNode = toNode
        self.transition = edge.transition
        self.id = edge.id
        self.transformAny = { any in
            guard let typedInput = any as? From.DataType else {
                fatalError("Type mismatch: expected input of type \(From.DataType.self) for edge \(edge.id), received \(type(of: any))")
            }
            let output = edge.transform(typedInput)
            return output
        }
    }

    /// Invokes the transformation on the provided source data,
    /// returning a value typed according to the destination node.
    func applyTransform(_ value: Any) -> Any {
        return transformAny(value)
    }
}

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
            let placeholder = ScreenNode<From.DataType>(edge.from.id)
            fromWrapped = AnyNavNode(placeholder)
        }
        let toWrapped: AnyNavNode
        if let existingTo = nodes[edge.to.id] {
            toWrapped = existingTo
        } else {
            let placeholder = ScreenNode<To.DataType>(edge.to.id)
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
/// node in a parent graph.  The `DataType` of the subgraph is the
/// same as the `DataType` of its start node.
public final class NavSubgraph<Start: NavNode>: NavNode {
    public typealias DataType = Start.DataType
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

// MARK: - Navigation controller

/// A `NavigationController` orchestrates the execution of flows defined
/// in a `NavigationGraph`.  It acts as the analogue of Android's
/// `NavController` by centralising navigation logic and keeping it
/// separate from your UI code.  Screens signal completion via an
/// asynchronous callback, and the controller consults the graph to
/// determine what happens next.
///
/// To use a `NavigationController`, provide it with a `NavigationGraph`
/// and a presenter closure.  The presenter is responsible for
/// instantiating and presenting the appropriate screen for a given
/// node and returning asynchronously when the user has completed the
/// screen.  The controller will then automatically follow the
/// corresponding edge (if any) by applying its transformation and
/// presenting the next screen.  When no outgoing edges exist, the
/// controller terminates the flow.
public final class NavigationController {
    /// The navigation graph describing the flow.
    private let graph: NavigationGraph
    /// A closure responsible for presenting a node and waiting for
    /// completion.  It receives an erased node and the input data and
    /// must return asynchronously the output data (which may be
    /// different from the input if the screen mutates its state).  For
    /// subgraphs, the controller automatically handles internal
    /// navigation and invokes this closure for each leaf node of the
    /// subgraph.
    private let presenter: (AnyNavNode, Any) async -> Any
    /// A decision handler invoked when a node has multiple outgoing
    /// edges.  By default the first edge is chosen.  Override this
    /// behaviour by providing a custom handler that selects an edge
    /// based on the current node, the available edges and the
    /// returned data from the presenter.
    private let decisionHandler: (AnyNavNode, [AnyNavEdge], Any) -> AnyNavEdge?

    /// Creates a new navigation controller for the given graph and
    /// presenter.  You may supply an optional decision handler.  The
    /// decision handler should return the edge to follow when a node
    /// has more than one outgoing edge.  If it returns `nil`, the
    /// controller stops navigating after the current node.
    public init(
        graph: NavigationGraph,
        presenter: @escaping (AnyNavNode, Any) async -> Any,
        decisionHandler: @escaping (AnyNavNode, [AnyNavEdge], Any) -> AnyNavEdge? = { node, edges, _ in
            return edges.first
        }
    ) {
        self.graph = graph
        self.presenter = presenter
        self.decisionHandler = decisionHandler
    }

    /// Starts navigating from the specified node using the provided
    /// initial data.  This method returns when there are no more
    /// outgoing edges to follow.  The initial node must be present
    /// within the controller's graph; otherwise, this method throws
    /// a runtime error.
    public func start<Start: NavNode>(at start: Start, with data: Start.DataType) async {
        guard let wrapped = graph.nodes[start.id] else {
            fatalError("Starting node \(start.id) is not registered in the graph")
        }
        await navigate(node: wrapped, data: data)
    }

    /// Runs a nested subgraph from outside of the main navigation flow.
    /// This method can be called from within a presenter to suspend
    /// the current flow, execute an independent subgraph, and return
    /// the result.  It mirrors the ability in Android's Navigation
    /// component to launch a nested graph from arbitrary points in
    /// your code.  The subgraph must be registered in the controller's
    /// underlying graph using `addSubgraph`.  The returned data is
    /// strongly typed to the subgraph's `DataType`.
    public func runSubgraph<Start: NavNode>(_ subgraph: NavSubgraph<Start>, with data: Start.DataType) async -> Start.DataType {
        // Look up the erased node corresponding to the subgraph in the
        // controller's graph.  If it does not exist, this is a programmer
        // error and we crash.
        guard let node = graph.nodes[subgraph.id] else {
            fatalError("Subgraph node \(subgraph.id) is not registered in the controller's graph")
        }
        // Extract the wrapper containing the nested graph and start node.
        guard let wrapper = node.subgraphWrapper else {
            fatalError("Node \(subgraph.id) is not a subgraph")
        }
        // Find the start node inside the nested graph.
        guard let startWrapped = wrapper.graph.nodes[wrapper.startNodeId] else {
            fatalError("Subgraph start node \(wrapper.startNodeId) is not registered in its graph")
        }
        // Run the subgraph asynchronously.  The returned value is
        // `Any`, but should match the subgraph's `DataType`.
        let resultAny = await runSubgraph(subgraph: wrapper, node: startWrapped, data: data)
        guard let typedResult = resultAny as? Start.DataType else {
            fatalError("Type mismatch in subgraph result: expected \(Start.DataType.self), got \(type(of: resultAny))")
        }
        return typedResult
    }

    /// Recursively navigates through the graph starting at the given
    /// node.  For each node, the controller invokes the presenter to
    /// display the screen and wait for completion.  It then looks up
    /// any outgoing edges.  If more than one edge exists, the
    /// decision handler is asked to choose which one to follow.
    private func navigate(node: AnyNavNode, data: Any) async {
        // If the node is a subgraph, run its internal graph starting
        // at the subgraph's start node and return the resulting data.
        if let wrapper = node.subgraphWrapper {
            // Find the start node in the subgraph and run the flow.
            guard let startWrapped = wrapper.graph.nodes[wrapper.startNodeId] else {
                fatalError("Subgraph start node \(wrapper.startNodeId) is not registered in its graph")
            }
            let result = await runSubgraph(subgraph: wrapper, node: startWrapped, data: data)
            // After completing the subgraph, treat the result as the data
            // returned from the subgraph node itself.  Continue
            // navigation using the result.
            await continueAfter(node: node, data: result)
            return
        }
        // Present the current node and wait for the user to complete
        // the screen.  The presenter returns the (possibly mutated)
        // data.
        let output = await presenter(node, data)
        await continueAfter(node: node, data: output)
    }

    /// Continues navigation after the current node based on the
    /// outgoing edges defined in the graph.  If no outgoing edges
    /// exist, this function returns and navigation stops.  If exactly
    /// one outgoing edge exists, it is followed automatically.  If
    /// multiple edges exist, the decision handler is consulted.
    private func continueAfter(node: AnyNavNode, data: Any) async {
        let edges = graph.adjacency[node.id] ?? []
        guard !edges.isEmpty else {
            // Reached the end of the flow.
            return
        }
        let chosen: AnyNavEdge
        if edges.count == 1 {
            chosen = edges[0]
        } else {
            guard let decision = decisionHandler(node, edges, data) else {
                // The handler indicated to stop navigation.
                return
            }
            chosen = decision
        }
        // Apply the edge transformation to produce the next data.
        let transformed = chosen.applyTransform(data)
        // Fetch the destination node wrapper; it must exist.
        guard let nextWrapped = graph.nodes[chosen.toNode.id] else {
            fatalError("Destination node \(chosen.toNode.id) is not registered in the graph")
        }
        // Navigate to the next node.
        await navigate(node: nextWrapped, data: transformed)
    }

    /// Runs a nested subgraph.  This helper function presents each
    /// node within the subgraph until there are no more outgoing
    /// edges.  It returns the final data produced by the last node in
    /// the subgraph.  Nested subgraphs within the subgraph are
    /// handled recursively.
    private func runSubgraph(subgraph: AnyNavNode.SubgraphWrapper, node: AnyNavNode, data: Any) async -> Any {
        // Detect if the current node is itself a subgraph.  Nested
        // subgraphs are handled recursively; we run the nested flow
        // first, then continue within the current subgraph.
        if let nested = node.subgraphWrapper {
            guard let startWrapped = nested.graph.nodes[nested.startNodeId] else {
                fatalError("Subgraph start node \(nested.startNodeId) is not registered in its graph")
            }
            let result = await runSubgraph(subgraph: nested, node: startWrapped, data: data)
            return await runSubgraph(subgraph: subgraph, node: node, data: result)
        }
        // Present the node using the main presenter's behaviour.
        let output = await presenter(node, data)
        // Look up edges in the subgraph's internal graph.
        let edges = subgraph.graph.adjacency[node.id] ?? []
        if edges.isEmpty {
            return output
        }
        let chosen: AnyNavEdge
        if edges.count == 1 {
            chosen = edges[0]
        } else {
            // We reuse the parent decision handler for subgraphs.
            guard let decision = decisionHandler(node, edges, output) else {
                return output
            }
            chosen = decision
        }
        let transformed = chosen.applyTransform(output)
        guard let nextWrapped = subgraph.graph.nodes[chosen.toNode.id] else {
            fatalError("Destination node \(chosen.toNode.id) is not registered in the subgraph")
        }
        return await runSubgraph(subgraph: subgraph, node: nextWrapped, data: transformed)
    }

    // The protocol `NavSubgraphProtocol` is now defined at the top level
    // of this file.  `NavSubgraph` conforms to it automatically.
    // We no longer need to define it here or provide casting logic.
}

#if DEBUG
/// A simple struct representing a user.  Used as data for the
/// profile screen in the example below.
struct User {
    let username: String
}

/// A helper function that constructs and exercises a navigation
/// graph.  You can call this function from your application's
/// entry point to see the library in action.
func exampleNavigationGraph() {
    let home = ScreenNode<Void>("home")
    let profile = ScreenNode<User>("profile")
    let settings = ScreenNode<Void>("settings")

    let graph = NavigationGraph()
    graph.addNode(home)
    graph.addNode(profile)
    graph.addNode(settings)

    graph.addEdge(Edge(from: home, to: profile, transition: .push) { _ in
        return User(username: "Alice")
    })
    graph.addEdge(Edge(from: profile, to: settings, transition: .modal) { _ in
        return ()
    })

    assert(graph.canNavigate(from: home, to: settings))
    assert(!graph.canNavigate(from: settings, to: profile))

    if let path = graph.findPath(from: home, to: settings) {
        print("Path from home to settings:\n\(graph.prettyPrintPath(path))")
    }

    let welcome = ScreenNode<Void>("welcome")
    let register = ScreenNode<User>("register")
    let onboardingGraph = NavigationGraph()
    onboardingGraph.addNode(welcome)
    onboardingGraph.addNode(register)
    onboardingGraph.addEdge(Edge(from: welcome, to: register, transition: .push) { _ in
        return User(username: "NewUser")
    })
    let onboarding = NavSubgraph(id: "onboarding", graph: onboardingGraph, start: welcome)
    graph.addSubgraph(onboarding)
    graph.addEdge(Edge(from: settings, to: onboarding, transition: .modal) { _ in
        return ()
    })

    if let path = graph.findPath(from: home.id, to: onboarding.id) {
        print("Path from home to onboarding:\n\(graph.prettyPrintPath(path))")
    }
    if let onboardingPath = onboarding.graph.findPath(from: welcome.id, to: register.id) {
        print("Path inside onboarding subgraph:\n\(onboarding.graph.prettyPrintPath(onboardingPath))")
    }
}
// Uncomment the line below to run the example when debugging this
// library.  It has no effect in release builds.
// exampleNavigationGraph()
#endif
*/





















/*
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

/// Describes the type of transition used to move from one screen to
/// another.  This enum intentionally mirrors the high‑level concepts
/// present in Android's Navigation component (push/hosted,
/// modal/dialog and pop) but can be extended to include custom
/// transition types specific to your application.
public enum TransitionType: CustomStringConvertible {
    /// A push transition inserts the destination onto the navigation
    /// stack.  In UIKit this typically corresponds to
    /// `UINavigationController.pushViewController(_:animated:)`.
    case push
    /// A modal transition presents the destination modally on top of
    /// the current context.  In UIKit this could be
    /// `present(_:animated:completion:)`.
    case modal
    /// A pop transition removes one or more destinations from the
    /// navigation stack.  This can be used when popping back to a
    /// previous screen.  Note that pop transitions are only valid
    /// when navigating back to an ancestor in the back stack.  They
    /// are included here for completeness but are not required for
    /// forward navigation.
    case pop

    /// A textual representation of the transition, used by the
    /// `prettyPrintPath` method to produce human‑readable output.
    public var description: String {
        switch self {
        case .push: return "push"
        case .modal: return "modal"
        case .pop: return "pop"
        }
    }
}

/// A protocol representing a node within the navigation graph.  Each
/// node has an associated `DataType` which describes the type of
/// information passed into that screen when it is navigated to.  For
/// screens that do not require any data, use `Void` as the
/// `DataType`.  Conforming types must provide a unique `id` that
/// identifies them within the graph.
public protocol NavNode {
    /// The type of data required to instantiate or present this
    /// destination.  This is analogous to the `@Serializable` route
    /// classes used in Android's Navigation component.  Using an
    /// associated type enforces that only data of this type can be
    /// passed to the node.
    associatedtype DataType
    /// A unique identifier for the node.  Two nodes with the same
    /// identifier are considered identical within the context of a
    /// single navigation graph.
    var id: String { get }
}

/// A simple concrete implementation of `NavNode` that can be used
/// directly to represent screens in your application.  Each
/// `ScreenNode` is parameterised by the type of data it accepts when
/// navigated to.  For example, a profile screen that requires a
/// `User` object could be defined as `let profileNode = ScreenNode<User>("profile")`.
public struct ScreenNode<Data>: NavNode {
    public typealias DataType = Data
    public let id: String
    public init(_ id: String) {
        self.id = id
    }
}

/// A directed edge between two nodes in the navigation graph.  An
/// edge encodes the type of transition used to navigate from the
/// source (`from`) to the destination (`to`) and contains a
/// transformation closure that maps the source's data type into the
/// destination's data type.  The closure is responsible for
/// preparing any data required by the destination based on the
/// information available in the source.  For nodes whose
/// `DataType` is `Void`, simply ignore the input parameter and
/// return an instance of the destination's `DataType`.
public struct Edge<From: NavNode, To: NavNode> {
    /// A unique identifier for the edge.  This can be useful when
    /// debugging or when multiple edges exist between the same pair
    /// of nodes.  If you do not care about edge identities you can
    /// leave this value as the default.
    public let id: String
    /// The source node of the edge.
    public let from: From
    /// The destination node of the edge.
    public let to: To
    /// The transition used to navigate between nodes.
    public let transition: TransitionType
    /// A function which transforms the source node's `DataType` into
    /// the destination node's `DataType`.  This enables compile‑time
    /// safety by ensuring that only valid data is passed when
    /// navigating between two specific node types.
    public let transform: (From.DataType) -> To.DataType

    /// Creates a new edge between the specified nodes with the given
    /// transition and data transformation.  The `id` parameter
    /// defaults to a generated string combining the source and
    /// destination identifiers but may be overridden for clarity.
    public init(
        id: String? = nil,
        from: From,
        to: To,
        transition: TransitionType,
        transform: @escaping (From.DataType) -> To.DataType
    ) {
        self.id = id ?? "\(from.id)->\(to.id)"
        self.from = from
        self.to = to
        self.transition = transition
        self.transform = transform
    }
}

// MARK: - Type erasure wrappers

/// An internal class used to erase the generic type of a `NavNode` so
/// that nodes of heterogeneous data types can be stored together in
/// collections.  Instances of `AnyNavNode` wrap a concrete node and
/// expose only the minimal information needed by the graph: the node's
/// identifier and the runtime type of its associated data.  It also
/// stores a type‑checking closure used to validate data passed to
/// transformation functions.
internal final class AnyNavNode {
    /// The node's unique identifier.
    let id: String
    /// The metatype of the associated data.
    let dataType: Any.Type
    /// A closure that verifies whether a given value is of the
    /// correct `DataType`.  Returns the typed value on success or nil
    /// otherwise.
    private let typeChecker: (Any) -> Any?
    /// The wrapped node.  This is stored to preserve identity when
    /// comparing nodes.  We do not expose it publicly to avoid
    /// leaking the associated type.
    private let _node: Any

    /// Wraps a concrete node in an `AnyNavNode`.
    init<N: NavNode>(_ node: N) {
        self.id = node.id
        self.dataType = N.DataType.self
        self._node = node
        self.typeChecker = { value in
            return value as? N.DataType
        }
    }

    /// Attempts to cast the provided `Any` value into this node's
    /// `DataType`.  Returns the typed value on success or nil on
    /// failure.
    func cast<Data>(_ value: Any, to _: Data.Type) -> Data? {
        return typeChecker(value) as? Data
    }
}

/// An internal class used to erase the generic types of an `Edge` so
/// that edges of heterogeneous source and destination types can be
/// stored together.  `AnyNavEdge` stores the nodes it connects, the
/// transition type and a type‑checked transformation closure which
/// converts arbitrary data into arbitrary data.  It will crash at
/// runtime if the incoming data type does not match the source node's
/// `DataType`.  This is by design: edge registration always performs
/// compile‑time checks on the closure types, and runtime checks here
/// guard against misconfiguration or misuse.
internal final class AnyNavEdge {
    /// The source node of the edge.
    let fromNode: AnyNavNode
    /// The destination node of the edge.
    let toNode: AnyNavNode
    /// The transition used to navigate between nodes.
    let transition: TransitionType
    /// A unique identifier for the edge.
    let id: String
    /// A transformation closure which accepts and returns values of
    /// type `Any`.  The closure performs runtime type checking and
    /// will `fatalError` if called with the wrong source data type.
    private let transformAny: (Any) -> Any

    /// Creates an erased edge from a concrete `Edge`.  You must
    /// provide the corresponding `AnyNavNode` instances for the
    /// source and destination.  An assertion is thrown if the
    /// provided nodes do not match the types of the edge.
    init<From: NavNode, To: NavNode>(
        _ edge: Edge<From, To>,
        from fromNode: AnyNavNode,
        to toNode: AnyNavNode
    ) {
        precondition(fromNode.id == edge.from.id,
                     "Mismatched 'from' node when creating AnyNavEdge")
        precondition(toNode.id == edge.to.id,
                     "Mismatched 'to' node when creating AnyNavEdge")
        self.fromNode = fromNode
        self.toNode = toNode
        self.transition = edge.transition
        self.id = edge.id
        self.transformAny = { any in
            guard let typedInput = any as? From.DataType else {
                fatalError("Type mismatch: expected input of type \(From.DataType.self) for edge \(edge.id), received \(type(of: any))")
            }
            let output = edge.transform(typedInput)
            return output
        }
    }

    /// Invokes the transformation on the provided source data,
    /// returning a value typed according to the destination node.
    func applyTransform(_ value: Any) -> Any {
        return transformAny(value)
    }
}

// MARK: - Navigation graph

/// A `NavigationGraph` stores a collection of nodes and the edges
/// connecting them.  It supports adding nodes and edges, querying
/// reachability, computing paths between nodes and pretty‑printing
/// paths for debugging.  Nodes and edges may be registered in any
/// order; edges referencing nodes that have not yet been added will
/// assert when used but can be added to the adjacency map in advance.
public final class NavigationGraph {
    /// A dictionary mapping node identifiers to their erased node
    /// wrappers.  Each entry must be unique.
    private var nodes: [String: AnyNavNode] = [:]
    /// An adjacency map from node identifiers to their outgoing
    /// edges.  Edges may be registered before the corresponding
    /// nodes, but will only be usable once both nodes are present.
    private var adjacency: [String: [AnyNavEdge]] = [:]

    /// Initializes an empty navigation graph.
    public init() {}

    // MARK: Node registration

    /// Adds a node to the graph.  If a node with the same id already
    /// exists, this method will replace it.  It is safe to add a
    /// node after registering edges; once both the source and
    /// destination nodes of an edge exist, that edge becomes valid.
    @discardableResult
    public func addNode<N: NavNode>(_ node: N) -> Self {
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
            let placeholder = ScreenNode<From.DataType>(edge.from.id)
            fromWrapped = AnyNavNode(placeholder)
        }
        let toWrapped: AnyNavNode
        if let existingTo = nodes[edge.to.id] {
            toWrapped = existingTo
        } else {
            let placeholder = ScreenNode<To.DataType>(edge.to.id)
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

    /// Generic overload of `findPath` that accepts node instances
    /// directly.  Returns a typed array of erased edges representing
    /// the path, or `nil` if no path exists.
    func findPath<From: NavNode, To: NavNode>(from source: From, to destination: To) -> [AnyNavEdge]? {
        return findPath(from: source.id, to: destination.id)
    }

    // MARK: Pretty printing

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
/// node in a parent graph.  The `DataType` of the subgraph is the
/// same as the `DataType` of its start node.
public final class NavSubgraph<Start: NavNode>: NavNode {
    public typealias DataType = Start.DataType
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

#if DEBUG
/// A simple struct representing a user.  Used as data for the
/// profile screen in the example below.
struct User {
    let username: String
}

/// A helper function that constructs and exercises a navigation
/// graph.  You can call this function from your application's
/// entry point to see the library in action.
func exampleNavigationGraph() {
    let home = ScreenNode<Void>("home")
    let profile = ScreenNode<User>("profile")
    let settings = ScreenNode<Void>("settings")

    let graph = NavigationGraph()
    graph.addNode(home)
    graph.addNode(profile)
    graph.addNode(settings)

    graph.addEdge(Edge(from: home, to: profile, transition: .push) { _ in
        return User(username: "Alice")
    })
    graph.addEdge(Edge(from: profile, to: settings, transition: .modal) { _ in
        return ()
    })

    assert(graph.canNavigate(from: home, to: settings))
    assert(!graph.canNavigate(from: settings, to: profile))

    if let path = graph.findPath(from: home, to: settings) {
        print("Path from home to settings:\n\(graph.prettyPrintPath(path))")
    }

    let welcome = ScreenNode<Void>("welcome")
    let register = ScreenNode<User>("register")
    let onboardingGraph = NavigationGraph()
    onboardingGraph.addNode(welcome)
    onboardingGraph.addNode(register)
    onboardingGraph.addEdge(Edge(from: welcome, to: register, transition: .push) { _ in
        return User(username: "NewUser")
    })
    let onboarding = NavSubgraph(id: "onboarding", graph: onboardingGraph, start: welcome)
    graph.addSubgraph(onboarding)
    graph.addEdge(Edge(from: settings, to: onboarding, transition: .modal) { _ in
        return ()
    })

    if let path = graph.findPath(from: home.id, to: onboarding.id) {
        print("Path from home to onboarding:\n\(graph.prettyPrintPath(path))")
    }
    if let onboardingPath = onboarding.graph.findPath(from: welcome.id, to: register.id) {
        print("Path inside onboarding subgraph:\n\(onboarding.graph.prettyPrintPath(onboardingPath))")
    }
}
// Uncomment the line below to run the example when debugging this
// library.  It has no effect in release builds.
// exampleNavigationGraph()
#endif
*/
