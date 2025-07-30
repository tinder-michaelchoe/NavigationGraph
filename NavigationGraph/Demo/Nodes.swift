//
//  Nodes.swift
//  NavigationGraph
//
//  Created by mexicanpizza on 7/30/25.
//

import UIKit

final class WelcomeNode: NavNode, ViewControllerProviding {
    
    typealias InputType = Void
    typealias OutputType = WelcomeViewController.WelcomeResult
    
    let viewControllerFactory: ((()) -> WelcomeViewController)? = { _ in
        return WelcomeViewController()
    }
}

final class SignInHomeNode: NavNode, ViewControllerProviding {
    
    typealias InputType = Void
    typealias OutputType = String?
    
    let viewControllerFactory: ((()) -> SigninViewController)? = { _ in
        return SigninViewController()
    }
}

final class ForgotPasswordNode: NavNode, ViewControllerProviding {
    
    typealias InputType = String?
    typealias OutputType = Void
    
    let viewControllerFactory: ((String?) -> ForgotPasswordViewController)? = { possibleEmail in
        return ForgotPasswordViewController(initialEmailAddress: possibleEmail)
    }
}

final class ProfileNode: NavNode, ViewControllerProviding {
    
    typealias InputType = User
    typealias OutputType = Bool
    
    let viewControllerFactory: ((()) -> NodeViewController)? = { _ in
        return NodeViewController(nodeId: "profile", colour: .systemBlue)
    }
}
