//
//  NavigableViewController.swift
//  NavigationGraph
//
//  Created by mexicanpizza on 7/29/25.
//

import UIKit

/// A protocol that view controllers must conform to for use with the navigation system.
///
/// `NavigableViewController` enables view controllers to communicate their completion
/// state and output data to the navigation system. When a screen's work is finished,
/// the view controller calls the completion handler to trigger navigation to the next screen.
///
/// ## Overview
///
/// The protocol defines a single property, `onComplete`, which serves as a callback
/// mechanism for notifying the navigation system when the user has finished interacting
/// with the screen. The completion data must match the associated node's `OutputType`.
///
/// ## Example Implementation
///
/// ```swift
/// class WelcomeViewController: UIViewController, NavigableViewController {
///     typealias CompletionType = WelcomeResult
///     
///     enum WelcomeResult {
///         case signIn
///         case createAccount
///         case skip
///     }
///     
///     var onComplete: ((WelcomeResult) -> Void)?
///     
///     @IBAction func signInTapped() {
///         onComplete?(.signIn)
///     }
///     
///     @IBAction func createAccountTapped() {
///         onComplete?(.createAccount)
///     }
/// }
/// ```
///
/// ## Integration with Navigation Nodes
///
/// View controllers conforming to this protocol are typically created by navigation
/// nodes that also conform to `ViewControllerProviding`. The navigation system
/// automatically sets up the completion handler when presenting the view controller.
///
/// ## Thread Safety
///
/// The completion handler should only be called from the main queue, as it triggers
/// navigation operations that involve UIKit components.
public protocol NavigableViewController: UIViewController {
    
    /// The type of data returned when the view controller completes.
    ///
    /// This type must match the `OutputType` of the associated navigation node.
    /// Use `Void` if the view controller produces no output data.
    associatedtype CompletionType
    
    /// A callback invoked when the view controller's work is complete.
    ///
    /// Call this closure to notify the navigation system that the user has finished
    /// interacting with this screen. The provided data will be used to determine
    /// the next navigation step based on the graph's edge predicates.
    ///
    /// ## Parameters
    /// - The completion data of type `CompletionType`
    ///
    /// ## Usage Guidelines
    /// - Call this closure when the user performs an action that should trigger navigation
    /// - Only call from the main queue
    /// - The data provided will be passed to edge predicates and transforms
    /// - It's safe to call this multiple times; subsequent calls are ignored
    ///
    /// ## Example
    /// ```swift
    /// @IBAction func saveButtonTapped() {
    ///     let userData = collectUserInput()
    ///     onComplete?(userData)
    /// }
    /// ```
    var onComplete: ((CompletionType) -> Void)? { get set }
}

/// A type-erased wrapper for any `NavigableViewController`.
///
/// `AnyNavigableViewController` enables the navigation system to work with view controllers
/// of different completion types without exposing generic type parameters. It provides
/// a uniform interface for setting completion handlers and accessing the wrapped view controller.
///
/// ## Overview
///
/// This wrapper is used internally by the navigation system to:
/// - Store heterogeneous view controller types in collections
/// - Provide type-erased completion handling
/// - Maintain identity relationships for cleanup operations
///
/// ## Type Safety
///
/// Although type-erased, the wrapper maintains type safety by performing runtime
/// type checks when setting completion handlers and invoking callbacks.
final class AnyNavigableViewController: UIViewController, NavigableViewController {
    /// The type-erased completion type, always `Any`.
    public typealias CompletionType = Any
    
    /// Internal type-erased wrapper for completion handling.
    private let box: AnyNavigableViewControllerBox
    
    /// The original wrapped view controller instance.
    ///
    /// This property provides access to the underlying view controller for
    /// identity comparisons and UIKit operations.
    let wrapped: AnyObject
    
    /// A type-erased completion handler that accepts `Any` output data.
    ///
    /// This property forwards completion calls to the underlying view controller's
    /// completion handler after performing appropriate type checking.
    public var onComplete: ((Any) -> Void)? {
        get { box.onComplete }
        set { box.onComplete = newValue }
    }
    
    /// Creates a type-erased wrapper for a navigable view controller.
    ///
    /// - Parameter base: The view controller to wrap
    /// - Requires: The base view controller must conform to both `NavigableViewController` and `UIViewController`
    ///
    /// ## Type Erasure Process
    ///
    /// The initializer creates an internal wrapper that handles type conversions
    /// between the specific completion type and the erased `Any` type.
    public init<VC: NavigableViewController>(_ base: VC) where VC: UIViewController {
        self.box = NavigableViewControllerBoxImpl(base)
        self.wrapped = base
        super.init(nibName: nil, bundle: nil)
    }
    
    /// Required initializer for NSCoder compliance.
    ///
    /// This initializer is not supported and will crash if called.
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension AnyNavigableViewController {
    
    /// The hash value of the wrapped view controller.
    ///
    /// This property forwards to the wrapped instance's hash value to maintain
    /// identity relationships in collections and mappings.
    override var hash: Int {
        wrapped.hash
    }
    
    /// Compares two type-erased view controllers for equality.
    ///
    /// Equality is based on the hash values of the wrapped view controllers.
    ///
    /// - Parameters:
    ///   - lhs: The first view controller to compare
    ///   - rhs: The second view controller to compare
    /// - Returns: `true` if the hash values match, `false` otherwise
    static func ==(lhs: AnyNavigableViewController, rhs: AnyNavigableViewController) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

/// Abstract base class for type-erased completion handling.
///
/// This class provides the interface for type-erased completion handlers
/// without exposing the specific generic types involved.
private class AnyNavigableViewControllerBox {
    /// The type-erased completion handler.
    ///
    /// Subclasses must override this property to provide actual functionality.
    var onComplete: ((Any) -> Void)? {
        get { fatalError("Must override") }
        set { fatalError("Must override") }
    }
}

/// Concrete implementation of type-erased completion handling.
///
/// This class wraps a specific `NavigableViewController` and provides type-safe
/// completion handling while exposing a type-erased interface.
private final class NavigableViewControllerBoxImpl<VC: NavigableViewController>: AnyNavigableViewControllerBox where VC: UIViewController {
    /// The wrapped view controller instance.
    private let base: VC
    
    /// Type-erased completion handler that performs runtime type checking.
    ///
    /// This property bridges between the type-erased `Any` interface and the
    /// specific completion type expected by the wrapped view controller.
    override var onComplete: ((Any) -> Void)? {
        get {
            guard let handler = base.onComplete else { return nil }
            return { anyVal in
                if let typed = anyVal as? VC.CompletionType {
                    handler(typed)
                }
            }
        }
        set {
            if let newHandler = newValue {
                base.onComplete = { val in newHandler(val) }
            } else {
                base.onComplete = nil
            }
        }
    }
    
    /// Creates a new wrapper for the specified view controller.
    ///
    /// - Parameter base: The view controller to wrap
    init(_ base: VC) {
        self.base = base
    }
}
