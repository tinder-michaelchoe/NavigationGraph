//
//  Edge.swift
//  NavigationGraph
//
//  Created by mexicanpizza on 7/29/25.
//

/// A directed edge between two nodes in the navigation graph.  An
/// edge encodes the type of transition used to navigate from the
/// source (`from`) to the destination (`to`) and contains a
/// transformation closure that maps the source's output type into the
/// destination's input type.  The closure is responsible for
/// preparing any data required by the destination based on the
/// information available from the source's output.  For nodes whose
/// `OutputType` is `Void`, simply ignore the input parameter and
/// return an instance of the destination's `InputType`.
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
    
    /// An optional predicate closure that determines whether this
    /// edge is taken based on the data returned from the source
    /// node's output.  If `predicate` is nil, the edge is always
    /// considered eligible.  When a node completes, the
    /// navigation controller evaluates the predicates of all
    /// outgoing edges and selects the first edge whose predicate
    /// returns `true`.
    public let predicate: ((From.OutputType) -> Bool)?
    
    /// A function which transforms the source node's `OutputType` into
    /// the destination node's `InputType`.  This enables compile‑time
    /// safety by ensuring that only valid data is passed when
    /// navigating between two specific node types.
    public let transform: (From.OutputType) -> To.InputType

    /// Creates a new edge between the specified nodes with the given
    /// transition and data transformation.  The `id` parameter
    /// defaults to a generated string combining the source and
    /// destination identifiers but may be overridden for clarity.
    public init(
        id: String? = nil,
        from: From,
        to: To,
        transition: TransitionType,
        predicate: ((From.OutputType) -> Bool)? = nil,
        transform: @escaping (From.OutputType) -> To.InputType
    ) {
        self.id = id ?? "\(from.id)->\(to.id)"
        self.from = from
        self.to = to
        self.transition = transition
        self.predicate = predicate
        self.transform = transform
    }
}

// MARK: - Type erasure wrappers

/// An internal class used to erase the generic types of an `Edge` so
/// that edges of heterogeneous source and destination types can be
/// stored together. `AnyNavEdge` stores the nodes it connects, the
/// transition type and a type‑checked transformation closure which
/// converts arbitrary output data into arbitrary input data.  It will crash at
/// runtime if the incoming data type does not match the source node's
/// `OutputType`.  This is by design: edge registration always performs
/// compile‑time checks on the closure types, and runtime checks here
/// guard against misconfiguration or misuse.
public final class AnyNavEdge {
    
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
    /// will `fatalError` if called with the wrong source output data type.
    private let transformAny: (Any) -> Any

    /// A predicate closure which accepts a value of type `Any` and
    /// returns a boolean indicating whether this edge should be taken.
    /// If the underlying `Edge` has no predicate, this closure always
    /// returns `true`.  Runtime type checking is performed to ensure
    /// the input matches the source node's `OutputType`.  A mismatch
    /// results in `false` to indicate the edge is not eligible.
    let predicateAny: (Any) -> Bool

    /// Creates an erased edge from a concrete `Edge`.  You must
    /// provide the corresponding `AnyNavNode` instances for the
    /// source and destination.  An assertion is thrown if the
    /// provided nodes do not match the types of the edge.
    public init<From: NavNode, To: NavNode>(
        _ edge: Edge<From, To>,
        from fromNode: AnyNavNode,
        to toNode: AnyNavNode
    ) {
        precondition(
            fromNode.id == edge.from.id,
            "Mismatched 'from' node when creating AnyNavEdge"
        )
        precondition(
            toNode.id == edge.to.id,
            "Mismatched 'to' node when creating AnyNavEdge"
        )
        self.fromNode = fromNode
        self.toNode = toNode
        self.transition = edge.transition
        self.id = edge.id
        self.transformAny = { any in
            guard let typedInput = any as? From.OutputType else {
                fatalError(
                    "Type mismatch: expected input of type \(From.OutputType.self) for edge \(edge.id), received \(type(of: any))"
                )
            }
            let output = edge.transform(typedInput)
            return output
        }
        
        // Wrap the predicate to accept Any.  If no predicate is defined,
        // default to true.  If a type mismatch occurs, return false
        // (the edge will be considered ineligible).
        self.predicateAny = { any in
            if let pred = edge.predicate {
                guard let typedInput = any as? From.OutputType else {
                    return false
                }
                return pred(typedInput)
            } else {
                return true
            }
        }
    }

    /// Invokes the transformation on the provided source data,
    /// returning a value typed according to the destination node.
    func applyTransform(_ value: Any) -> Any {
        return transformAny(value)
    }
}
