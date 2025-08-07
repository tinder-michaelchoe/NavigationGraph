//
//  NavigableViewController.swift
//  NavigationGraph
//
//  Created by mexicanpizza on 7/29/25.
//

import UIKit

/// A protocol that view controllers used by `NavigationController` must
/// conform to.  It exposes an `onComplete` callback which should be
/// invoked when the user has finished interacting with the screen.  The
/// parameter to `onComplete` is the data returned from the screen and
/// must match the node's `OutputType`.
public protocol NavigableViewController: UIViewController {
    
    associatedtype CompletionType
    
    /// Call this closure when the view controller's work is  complete.  Pass back any data produced by the screen.
    var onComplete: ((CompletionType) -> Void)? { get set }
}

/// Type-erased wrapper for any NavigableViewController.
/// Allows using onComplete in a type-erased manner with Any payload.
final class AnyNavigableViewController: UIViewController, NavigableViewController {
    public typealias CompletionType = Any
    
    private let box: AnyNavigableViewControllerBox
    
    let wrapped: AnyObject
    
    /// Called when the view controller completes with any output.
    public var onComplete: ((Any) -> Void)? {
        get { box.onComplete }
        set { box.onComplete = newValue }
    }
    
    public init<VC: NavigableViewController>(_ base: VC) where VC: UIViewController {
        self.box = NavigableViewControllerBoxImpl(base)
        self.wrapped = base
        super.init(nibName: nil, bundle: nil)
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension AnyNavigableViewController {
    
    override var hash: Int {
        wrapped.hash
    }
    
    static func ==(lhs: AnyNavigableViewController, rhs: AnyNavigableViewController) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}

private class AnyNavigableViewControllerBox {
    var onComplete: ((Any) -> Void)? {
        get { fatalError("Must override") }
        set { fatalError("Must override") }
    }
}

private final class NavigableViewControllerBoxImpl<VC: NavigableViewController>: AnyNavigableViewControllerBox where VC: UIViewController {
    private let base: VC
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
    init(_ base: VC) {
        self.base = base
    }
}
