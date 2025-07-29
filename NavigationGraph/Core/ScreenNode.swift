//
//  ScreenNode.swift
//  NavigationGraph
//
//  Created by mexicanpizza on 7/29/25.
//

import SwiftUI
import UIKit

/// A simple concrete implementation of `NavNode` that can be used
/// directly to represent screens in your application.  Each
/// `ScreenNode` is parameterised by the type of data it accepts when
/// navigated to and the type of data it produces when navigation
/// completes.  For example, a profile screen that requires a
/// `User` object and produces no output could be defined as
/// `let profileNode = ScreenNode<User, Void>("profile")`.
public struct ScreenNode<Input, Output>: NavNode, ViewControllerProviding {
    public typealias InputType = Input
    public typealias OutputType = Output
    
    public let id: String
    let viewControllerFactory: ((Any) -> UIViewController & NavigableViewController)?
    
    public init(
        _ id: String,
        viewControllerFactory: ((Input) -> UIViewController & NavigableViewController)? = nil
    ) {
        self.id = id
        self.viewControllerFactory = { input in
            return (viewControllerFactory?((input as? InputType)!))!
        }
    }
}

protocol ViewControllerProviding {
    var viewControllerFactory: ((_ data: Any) -> UIViewController & NavigableViewController)? { get }
}
/*
protocol ViewProviding {
    var viewFactory: ((_ data: Any?) -> (any View & NavigableViewController))? { get }
}
*/
