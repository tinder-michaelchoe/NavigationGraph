//
//  Nodes.swift
//  NavigationGraph
//
//  Created by mexicanpizza on 7/30/25.
//

import PhotosUI
import UIKit

final class ProfileNode: NavNode, ViewControllerProviding {
    
    typealias InputType = User
    typealias OutputType = Bool
    
    let viewControllerFactory: (()) -> NodeViewController = { _ in
        return NodeViewController(nodeId: "profile", colour: .systemBlue)
    }
}

final class GenderLearnMoreNode: NavNode, ViewControllerProviding {

    typealias InputType = Void
    typealias OutputType = Void

    let viewControllerFactory: (()) -> NodeViewController = { _ in
        return NodeViewController(nodeId: "GenderLearnMoreNode", colour: .systemBlue)
    }
}
