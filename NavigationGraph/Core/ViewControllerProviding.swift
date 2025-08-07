import UIKit

/// A protocol for types that can create view controllers for navigation nodes.
///
/// `ViewControllerProviding` defines the interface for factory objects that create
/// view controller instances based on input data. This protocol enables type-safe
/// view controller creation while supporting dependency injection and data flow.
///
/// ## Overview
///
/// Navigation nodes typically conform to this protocol to provide view controllers
/// for their associated screens. The factory function receives input data and
/// returns a configured view controller ready for presentation.
///
/// ## Example Implementation
///
/// ```swift
/// final class ProfileNode: NavNode, ViewControllerProviding {
///     typealias InputType = User
///     typealias OutputType = ProfileResult
///     
///     let viewControllerFactory: (User) -> ProfileViewController = { user in
///         let controller = ProfileViewController()
///         controller.configure(with: user)
///         return controller
///     }
/// }
/// ```
///
/// ## Type Safety
///
/// The protocol ensures that:
/// - Input data types match between nodes and their view controllers
/// - View controllers are properly typed for their intended purpose
/// - Factory functions receive the correct data at compile time
protocol ViewControllerProviding {
    /// The type of input data required to create the view controller.
    ///
    /// This type must match the navigation node's `InputType` to ensure
    /// type-safe data flow during navigation.
    associatedtype Input
    
    /// The type of view controller created by this factory.
    ///
    /// The view controller must conform to `NavigableViewController` to enable
    /// communication with the navigation system.
    associatedtype ViewController: NavigableViewController
    
    /// A factory function that creates view controller instances.
    ///
    /// This function receives input data and returns a configured view controller
    /// ready for presentation. The function should set up any necessary
    /// dependencies, configure the UI state, and prepare the controller for user interaction.
    ///
    /// ## Parameters
    /// - `data`: Input data of type `Input` used to configure the view controller
    ///
    /// ## Returns
    /// A configured view controller instance of type `ViewController`
    ///
    /// ## Example
    /// ```swift
    /// let viewControllerFactory: (UserProfile) -> ProfileViewController = { profile in
    ///     let controller = ProfileViewController()
    ///     controller.userProfile = profile
    ///     controller.delegate = self
    ///     return controller
    /// }
    /// ```
    var viewControllerFactory: (_ data: Input) -> ViewController { get }
}

/// A type-erased wrapper for any `ViewControllerProviding` instance.
///
/// `AnyViewControllerProviding` enables the navigation system to work with view controller
/// factories of different input and output types without exposing generic type parameters.
/// It provides a uniform interface for creating view controllers while maintaining type safety
/// through runtime checks.
///
/// ## Overview
///
/// This wrapper is used internally by the navigation system to:
/// - Store heterogeneous factory types in collections
/// - Provide type-erased view controller creation
/// - Maintain type safety through runtime type checking
/// - Bridge between strongly-typed nodes and the type-erased navigation infrastructure
///
/// ## Type Safety
///
/// The wrapper performs runtime type checking to ensure that input data matches
/// the expected type. If type mismatches occur, the system will crash with
/// a descriptive error message indicating the expected and actual types.
///
/// ## Example Usage
///
/// ```swift
/// let typedFactory = ProfileNodeFactory()
/// let erasedFactory = AnyViewControllerProviding(typedFactory)
/// 
/// // The erased factory maintains type safety
/// let viewController = erasedFactory.viewControllerFactory(userData)
/// ```
public struct AnyViewControllerProviding: ViewControllerProviding {
    /// The type-erased input type, always `Any`.
    public typealias Input = Any
    
    /// The type-erased view controller type.
    typealias ViewController = AnyNavigableViewController
    
    /// Internal type-erased factory function.
    ///
    /// This function performs runtime type checking on the input data before
    /// forwarding to the underlying typed factory function.
    private let _viewControllerFactory: (Any) -> AnyNavigableViewController
    
    /// The type-erased view controller factory.
    ///
    /// This property provides a factory function that accepts `Any` input data
    /// and returns a type-erased view controller. Runtime type checking ensures
    /// that the input data matches the expected type.
    ///
    /// ## Type Checking
    ///
    /// If the input data cannot be cast to the expected type, the factory will
    /// crash with a fatal error indicating the type mismatch. This behavior
    /// helps catch configuration errors during development.
    ///
    /// ## Returns
    /// A type-erased view controller wrapped in `AnyNavigableViewController`
    var viewControllerFactory: (Any) -> AnyNavigableViewController {
        return { value in
            return _viewControllerFactory(value)
        }
    }
    
    /// Creates a type-erased wrapper for a view controller factory.
    ///
    /// - Parameter base: The typed view controller factory to wrap
    ///
    /// ## Type Erasure Process
    ///
    /// The initializer creates an internal factory function that:
    /// 1. Attempts to cast the input data to the expected type
    /// 2. Calls the underlying typed factory if successful
    /// 3. Wraps the result in a type-erased container
    /// 4. Crashes with a descriptive error if type casting fails
    ///
    /// ## Example
    /// ```swift
    /// let profileFactory = ProfileNodeFactory() // implements ViewControllerProviding
    /// let erasedFactory = AnyViewControllerProviding(profileFactory)
    /// ```
    init<T: ViewControllerProviding>(_ base: T) {
        self._viewControllerFactory = { input in
            // Attempt to cast and forward to the underlying factory
            guard let typedInput = input as? T.Input else {
                fatalError("Type mismatch in AnyViewControllerProviding for input: \(type(of: input)) should be \(T.Input.self)")
            }
            return AnyNavigableViewController(base.viewControllerFactory(typedInput))
        }
    }
}
