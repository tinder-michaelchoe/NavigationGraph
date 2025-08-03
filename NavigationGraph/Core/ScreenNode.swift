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
public final class ScreenNode<Input, Output>: NavNode, ViewControllerProviding {
    public typealias InputType = Input
    public typealias OutputType = Output
    
    public var id: String {
        return "\(Self.self).\(_id)"
    }
    private let _id: String
    let viewControllerFactory: (Input) -> NodeViewController
    
    public init(
        _ id: String,
        viewControllerFactory: @escaping (Input) -> NodeViewController
    ) {
        self._id = id
        self.viewControllerFactory = viewControllerFactory
    }
}
