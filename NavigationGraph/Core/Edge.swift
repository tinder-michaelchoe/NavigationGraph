//
//  Edge.swift
//  NavigationGraph
//
//  Created by mexicanpizza on 7/29/25.
//

/// A directed edge connecting two nodes in a navigation graph.
///
/// An edge defines how users can navigate from one screen to another, including
/// the transition animation, conditional logic, and data transformation required.
///
/// ## Overview
///
/// Each edge encapsulates:
/// - **Source and destination nodes**: Where navigation begins and ends
/// - **Transition type**: How the navigation is presented (push, modal, etc.)
/// - **Predicate**: Optional condition that must be met for this edge to be taken
/// - **Transform**: Function to convert the source's output into the destination's input
///
/// ## Type Safety
///
/// Edges provide compile-time type safety by ensuring that:
/// - The source node's `OutputType` matches the predicate parameter type
/// - The transform function converts from `OutputType` to the destination's `InputType`
/// - Data flows correctly between screens without runtime type errors
///
/// ## Example
///
/// ```swift
/// let edge = Edge(
///     from: welcomeNode,
///     to: profileNode,
///     transition: .push,
///     predicate: { result in result == .viewProfile },
///     transform: { _ in currentUser }
/// )
/// ```
///
/// ## Conditional Navigation
///
/// Use predicates to create branching navigation flows:
///
/// ```swift
/// // Navigate to different screens based on user type
/// graph.addEdge(Edge(
///     from: loginNode,
///     to: adminDashboard,
///     transition: .push,
///     predicate: { user in user.isAdmin }
/// ))
///
/// graph.addEdge(Edge(
///     from: loginNode,
///     to: userDashboard,
///     transition: .push,
///     predicate: { user in !user.isAdmin }
/// ))
/// ```
public struct Edge<From: NavNode, To: NavNode> {
    
    /// A unique identifier for this edge.
    ///
    /// If not provided during initialization, defaults to "\(from.id)->\(to.id)".
    public let id: String
    
    /// The source node where navigation begins.
    public let from: From
    
    /// The destination node where navigation ends.
    public let to: To
    
    /// The transition animation used for this navigation.
    ///
    /// Common transitions include:
    /// - `.push`: Standard navigation controller push
    /// - `.modal`: Present modally
    /// - `.pop`: Navigate backward
    /// - `.dismiss`: Dismiss modal presentation
    public let transition: TransitionType
    
    /// An optional condition that determines when this edge can be taken.
    ///
    /// The predicate receives the source node's output data and returns `true`
    /// if this edge should be followed. If `nil`, the edge is always eligible.
    ///
    /// When multiple edges exist from the same node, the navigation controller
    /// evaluates predicates in order and takes the first edge that returns `true`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// predicate: { userInput in
    ///     userInput.age >= 18
    /// }
    /// ```
    public let predicate: ((From.OutputType) -> Bool)?
    
    /// A function that transforms the source node's output into the destination's input.
    ///
    /// This transformation ensures type-safe data flow between screens. The function
    /// receives the data produced by the source screen and must return data of the
    /// type expected by the destination screen.
    ///
    /// ## Example
    ///
    /// ```swift
    /// transform: { welcomeResult in
    ///     switch welcomeResult {
    ///     case .createAccount(let email):
    ///         return RegistrationData(email: email)
    ///     case .signIn:
    ///         return LoginData()
    ///     }
    /// }
    /// ```
    public let transform: (From.OutputType) -> To.InputType

    /// Creates a new navigation edge between two nodes.
    ///
    /// - Parameters:
    ///   - id: Optional unique identifier. Defaults to "\(from.id)->\(to.id)"
    ///   - from: The source node
    ///   - to: The destination node
    ///   - transition: The transition type for this navigation
    ///   - predicate: Optional condition for taking this edge
    ///   - transform: Function to convert source output to destination input
    ///
    /// ## Example
    ///
    /// ```swift
    /// let edge = Edge(
    ///     id: "welcome-to-profile",
    ///     from: welcomeNode,
    ///     to: profileNode,
    ///     transition: .push,
    ///     predicate: { $0 == .viewProfile },
    ///     transform: { _ in currentUser }
    /// )
    /// ```
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
    
    /// Creates a new navigation edge where the destination expects no input.
    ///
    /// This convenience initializer is used when the destination node's `InputType` is `Void`.
    /// The transform function defaults to returning `()`.
    ///
    /// - Parameters:
    ///   - id: Optional unique identifier. Defaults to "\(from.id)->\(to.id)"
    ///   - from: The source node
    ///   - to: The destination node (must have `InputType` of `Void`)
    ///   - transition: The transition type for this navigation
    ///   - predicate: Optional condition for taking this edge
    ///   - transform: Optional transform function, defaults to returning `()`
    ///
    /// ## Example
    ///
    /// ```swift
    /// let edge = Edge(
    ///     from: profileNode,
    ///     to: settingsNode, // SettingsNode.InputType is Void
    ///     transition: .push,
    ///     predicate: { $0 == .openSettings }
    /// )
    /// ```
    public init(
        id: String? = nil,
        from: From,
        to: To,
        transition: TransitionType,
        predicate: ((From.OutputType) -> Bool)? = nil,
        transform: @escaping (From.OutputType) -> To.InputType = { _ in return () }
    ) where To.InputType == Void {
        self.id = id ?? "\(from.id)->\(to.id)"
        self.from = from
        self.to = to
        self.transition = transition
        self.predicate = predicate
        self.transform = transform
    }
}

// MARK: - Type erasure wrappers

/// A type-erased wrapper for navigation edges.
///
/// `AnyNavEdge` enables storing edges with different generic types in the same collection.
/// It preserves the edge's behavior while hiding the specific source and destination types.
///
/// ## Overview
///
/// The navigation graph uses `AnyNavEdge` internally to store heterogeneous edge types
/// in the adjacency map. This type erasure is essential for the graph's flexibility
/// while maintaining type safety through runtime checks.
///
/// ## Type Safety
///
/// Although type-erased, `AnyNavEdge` maintains type safety through:
/// - Runtime type checking in predicate evaluation
/// - Runtime type checking in data transformation
/// - Graceful handling of type mismatches (especially for subgraph exits)
///
/// ## Error Handling
///
/// When type mismatches occur (commonly during subgraph navigation), the edge
/// attempts to provide safe fallback behavior rather than crashing.
final class AnyNavEdge {

    /// The source node of this edge.
    let fromNode: AnyNavNode
    
    /// The destination node of this edge.
    let toNode: AnyNavNode
    
    /// The transition type used for this navigation.
    let transition: TransitionType
    
    /// The unique identifier for this edge.
    let id: String
    
    /// A type-erased transformation function.
    ///
    /// This function accepts and returns values of type `Any`, performing runtime
    /// type checking to ensure compatibility. If types don't match, it attempts
    /// to provide safe fallback behavior.
    private let transformAny: (Any) -> Any

    /// A type-erased predicate function.
    ///
    /// This function accepts a value of type `Any` and returns whether this edge
    /// should be taken. If no predicate was defined or type checking fails,
    /// it returns `true` to maintain navigation flow.
    let predicateAny: (Any) -> Bool

    /// Creates a type-erased edge from a concrete `Edge`.
    ///
    /// - Parameters:
    ///   - edge: The concrete edge to wrap
    ///   - fromNode: The type-erased source node
    ///   - toNode: The type-erased destination node
    /// - Precondition: The provided nodes must match the edge's source and destination
    ///
    /// ## Type Erasure Process
    ///
    /// This initializer wraps the edge's predicate and transform functions to work
    /// with `Any` types while preserving their original behavior through runtime
    /// type checking.
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
                // Type mismatch occurred. This commonly happens with subgraph exits
                // where the current node's output type doesn't match the subgraph's
                // expected output type. Instead of crashing, we'll try to provide
                // a safe fallback.
                print("[NAV DEBUG]: Type mismatch in transform: expected \(From.OutputType.self), received \(type(of: any))")
                print("[NAV DEBUG]: Using fallback transformation for subgraph exit scenario")
                
                // For subgraph exits, we often just need to navigate to the next node
                // regardless of the specific data. Try to return a safe default value.
                if To.InputType.self == Void.self {
                    // If the destination expects Void, return void
                    return ()
                } else {
                    // For other types, we can't safely create an instance, but we can
                    // try to pass the original data and hope the destination can handle it
                    print("[NAV DEBUG]: Passing original data to destination, hoping it can handle type: \(type(of: any))")
                    return any
                }
            }
            let output = edge.transform(typedInput)
            return output
        }
        
        // Wrap the predicate to accept Any.  If no predicate is defined,
        // default to true.
        self.predicateAny = { any in
            guard
                    let predicate = edge.predicate,
                    let typedInput = any as? From.OutputType
            else {
                return true
            }
            return predicate(typedInput)
        }
    }

    /// Applies the transformation function to the provided source data.
    ///
    /// - Parameter value: The output data from the source node
    /// - Returns: The transformed data for the destination node
    ///
    /// ## Type Safety
    ///
    /// This method performs runtime type checking and attempts to provide
    /// safe fallback behavior if type mismatches occur.
    func applyTransform(_ value: Any) -> Any {
        return transformAny(value)
    }
}
