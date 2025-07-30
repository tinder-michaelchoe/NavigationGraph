import UIKit

protocol ViewControllerProviding {
    associatedtype Input
    
    var viewControllerFactory: ((_ data: Input) -> any NavigableViewController)? { get }
}

/// A type-erased wrapper for any `ViewControllerProviding`.
public struct AnyViewControllerProviding: ViewControllerProviding {
    public typealias Input = Any
    
    private let _viewControllerFactory: ((Any) -> AnyNavigableViewController)?
    
    var viewControllerFactory: ((Any) -> any NavigableViewController)? {
        return { value in
            return _viewControllerFactory?(value).wrapped as! any NavigableViewController
        }
    }
    
    init<T: ViewControllerProviding>(_ base: T) {
        if let factory = base.viewControllerFactory {
            self._viewControllerFactory = { input in
                // Attempt to cast and forward to the underlying factory
                guard let typedInput = input as? T.Input else {
                    fatalError("Type mismatch in AnyViewControllerProviding for input: \(type(of: input)) should be \(T.Input.self)")
                }
                return AnyNavigableViewController(factory(typedInput))
            }
        } else {
            self._viewControllerFactory = nil
        }
    }
}
