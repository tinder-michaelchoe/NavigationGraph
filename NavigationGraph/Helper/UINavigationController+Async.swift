//
//  UINavigationController+Async.swift
//  NavigationGraph
//
//  Created by Michael Choe on 11/6/25.
//

import UIKit

extension UINavigationController {

    func dismiss(animated: Bool) async {
        await withCheckedContinuation { continuation in
            dismiss(animated: animated) {
                continuation.resume()
            }
        }
    }
}
