//
//  TransitionType.swift
//  NavigationGraph
//
//  Created by mexicanpizza on 7/29/25.
//

/// Defines the type of transition animation used when navigating between nodes.
///
/// `TransitionType` specifies how the user interface should animate when moving
/// from one screen to another. Each transition type corresponds to standard
/// UIKit navigation patterns and behaviors.
///
/// ## Overview
///
/// The navigation system supports various transition types to match different
/// user interaction patterns and navigation flows. Choose the appropriate
/// transition based on the relationship between screens and the desired user experience.
///
/// ## Example Usage
///
/// ```swift
/// // Forward navigation
/// let forwardEdge = Edge(
///     from: welcomeNode,
///     to: profileNode,
///     transition: .push,
///     transform: { _ in userData }
/// )
///
/// // Modal presentation
/// let modalEdge = Edge(
///     from: mainNode,
///     to: settingsNode,
///     transition: .modal,
///     transform: { _ in () }
/// )
///
/// // Backward navigation
/// let backEdge = Edge(
///     from: detailNode,
///     to: listNode,
///     transition: .pop,
///     transform: { _ in () }
/// )
/// ```
public enum TransitionType: Equatable, CustomStringConvertible {

    case clearStackAndPush

    /// Dismiss a modally presented view controller.
    ///
    /// Use this to close modal presentations and return to the underlying
    /// view controller that originally presented the modal.
    ///
    /// ## Behavior
    /// - Dismisses the current modal presentation
    /// - Animates with a top-to-bottom slide transition
    /// - Returns to the presenting view controller
    case dismiss

    /// Modal presentation over the current view controller.
    ///
    /// Use this for temporary screens, settings, or flows that are conceptually
    /// separate from the main navigation hierarchy.
    ///
    /// ## Behavior
    /// - Presents the view controller modally
    /// - Slides up from the bottom by default
    /// - Does not add to the navigation stack
    /// - Requires explicit dismissal
    case modal

    /// No visual transition - used for data-only navigation.
    ///
    /// Use this when you need to update the navigation state without changing
    /// the visible view controller. This is useful for updating data models
    /// or triggering side effects.
    ///
    /// ## Behavior
    /// - No animation or view controller change
    /// - Updates internal navigation state only
    /// - Useful for data processing nodes
    case none

    /// Navigate backward by popping the current view controller.
    ///
    /// Use this to programmatically trigger backward navigation, equivalent
    /// to the user tapping the back button.
    ///
    /// ## Behavior
    /// - Removes the current view controller from the stack
    /// - Animates with a left-to-right slide transition
    /// - Returns to the previous view controller
    case pop

    /// Pop to a specific index in the navigation stack.
    ///
    /// Use this to navigate back multiple levels in the navigation hierarchy,
    /// such as returning to the root or a specific ancestor view controller.
    ///
    /// - Parameter Int: The target index in the navigation stack (0 = root)
    ///
    /// ## Behavior
    /// - Removes multiple view controllers from the stack
    /// - Animates to the target view controller
    /// - Index 0 returns to the root view controller
    ///
    /// ## Example
    /// ```swift
    /// // Return to the root view controller
    /// let rootEdge = Edge(
    ///     from: deepNode,
    ///     to: rootNode,
    ///     transition: .popTo(0),
    ///     transform: { _ in () }
    /// )
    /// ```
    case popTo(Int)

    /// Standard navigation controller push animation.
    ///
    /// Use this for forward navigation in hierarchical flows. The new view controller
    /// slides in from the right, and the back button appears automatically.
    ///
    /// ## Behavior
    /// - Adds the new view controller to the navigation stack
    /// - Animates with a right-to-left slide transition
    /// - Provides automatic back button functionality
    /// - Updates the navigation bar title
    case push

    /// A human-readable description of the transition type.
    ///
    /// This property provides string representations suitable for logging
    /// and debugging navigation flows.
    public var description: String {
        switch self {
        case .clearStackAndPush:
            return "clearStackAndPush"
        case .dismiss:
            return "dismiss"
        case .modal:
            return "modal"
        case .none:
            return "none"
        case .pop:
            return "pop"
        case .popTo(let index):
            return "popTo \(index)"
        case .push:
            return "push"
        }
    }
}
