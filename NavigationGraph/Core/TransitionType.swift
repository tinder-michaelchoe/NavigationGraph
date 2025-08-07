//
//  TransitionType.swift
//  NavigationGraph
//
//  Created by mexicanpizza on 7/29/25.
//

public enum TransitionType: Equatable, CustomStringConvertible {
    case push
    case modal
    case none
    case pop
    case popTo(Int)
    case dismiss

    public var description: String {
        switch self {
        case .push: return "push"
        case .none: return "none"
        case .modal: return "modal"
        case .pop: return "pop"
        case .popTo(let index): return "popTo \(index)"
        case .dismiss: return "dismiss"
        }
    }
}
