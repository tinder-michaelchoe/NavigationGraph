//
//  UIView+Extensions.swift
//  NavigationGraph
//
//  Created by mexicanpizza on 7/29/25.
//

import UIKit

extension UIView {
    func addAutolayoutSubview(_ view: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
    }
}
