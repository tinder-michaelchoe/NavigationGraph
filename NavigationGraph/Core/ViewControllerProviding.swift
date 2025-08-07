import UIKit

protocol ViewControllerProviding {
    associatedtype Input
    associatedtype ViewController: NavigableViewController
    
    var viewControllerFactory: (_ data: Input) -> ViewController { get }
}

/// A type-erased wrapper for any `ViewControllerProviding`.
public struct AnyViewControllerProviding: ViewControllerProviding {
    public typealias Input = Any
    typealias ViewController = AnyNavigableViewController
    
    private let _viewControllerFactory: (Any) -> AnyNavigableViewController
    
    var viewControllerFactory: (Any) -> AnyNavigableViewController {
        return { value in
            return _viewControllerFactory(value)
        }
    }
    
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
