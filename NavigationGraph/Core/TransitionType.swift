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
    /// Pop transitions are only valid when navigating back to an ancestor in the back stack.
    case pop
    case popTo(Int)
    case dismiss

    /// A textual representation of the transition, used by the
    /// `prettyPrintPath` method to produce human‑readable output.
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
