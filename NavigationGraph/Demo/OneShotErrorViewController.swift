//
//  ErrorViewController.swift
//  NavigationGraph
//
//  Created by Michael Choe on 8/1/25.
//

import Combine
import SwiftUI
import UIKit

final class OneShotAlertNode: NavNode, ViewControllerProviding {
    typealias Input = (String, String)

    typealias InputType = (String, String)
    typealias OutputType = Void

    let viewControllerFactory: (Input) -> OneShotAlertViewController = { tuple in
        let (title, message) = tuple
        let alert = OneShotAlertViewController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: { [weak alert] action in
            alert?.onComplete?(())
        }))
        return alert
    }
}

class OneShotAlertViewController: UIAlertController, NavigableViewController {

    var onComplete: ((()) -> Void)?
}
