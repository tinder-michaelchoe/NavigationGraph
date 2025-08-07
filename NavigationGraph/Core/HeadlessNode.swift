//
//  HeadlessNode.swift
//  NavigationGraph
//
//  Created by mexicanpizza on 7/30/25.
//

/// A navigation node that represents data processing or logical operations without a user interface.
///
/// `HeadlessNode` provides a way to include non-visual processing steps in your navigation flow.
/// These nodes don't present view controllers but can perform data transformations, API calls,
/// validation, or other business logic as part of the navigation sequence.
///
/// ## Overview
///
/// Headless nodes are useful for:
/// - **Data processing**: Transform or validate data between screens
/// - **API calls**: Fetch data needed for subsequent screens
/// - **Business logic**: Perform calculations or decision-making
/// - **Side effects**: Trigger analytics, logging, or other operations
/// - **Conditional routing**: Act as decision points in navigation flows
///
/// ## Type Parameters
///
/// - `Input`: The data type required for processing
/// - `Output`: The data type produced after processing
///
/// ## Example Usage
///
/// ```swift
/// // Create a headless node for data validation
/// let validationNode = HeadlessNode<UserData, ValidationResult>(
///     id: "validateUser"
/// )
///
/// // Use in a navigation graph
/// graph.addNode(validationNode)
/// graph.addEdge(Edge(
///     from: inputNode,
///     to: validationNode,
///     transition: .none, // No visual transition
///     transform: { userData in userData }
/// ))
/// ```
///
/// ## Integration with Navigation System
///
/// Since headless nodes don't present view controllers, they typically use:
/// - `.none` transition type to avoid visual changes
/// - Immediate completion with processed output data
/// - Edge transforms to handle data flow to subsequent nodes
///
/// ## Limitations
///
/// - Cannot display user interfaces
/// - Must complete processing synchronously
/// - Limited to data transformation and side effects
/// - Cannot directly handle user interaction
final class HeadlessNode<Input, Output>: NavNode {
    /// The input data type for this headless node.
    typealias InputType = Input
    
    /// The output data type for this headless node.
    typealias OutputType = Output
    
    /// The unique identifier for this headless node.
    ///
    /// The identifier is used to reference this node in the navigation graph
    /// and distinguish it from other nodes in the system.
    var id: String
    
    /// Creates a new headless node with the specified identifier.
    ///
    /// - Parameter id: A unique identifier for this headless node
    ///
    /// ## Example
    /// ```swift
    /// let processingNode = HeadlessNode<RawData, ProcessedData>(
    ///     id: "dataProcessor"
    /// )
    /// ```
    ///
    /// ## Identifier Guidelines
    /// 
    /// Choose descriptive identifiers that clearly indicate the node's purpose:
    /// - "validateInput"
    /// - "fetchUserProfile" 
    /// - "calculateTotals"
    /// - "logAnalytics"
    init(id: String) {
        self.id = id
    }
}
