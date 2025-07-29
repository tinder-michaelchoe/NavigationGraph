//
//  TransitionType.swift
//  NavigationGraph
//
//  Created by mexicanpizza on 7/29/25.
//

public enum TransitionType: CustomStringConvertible {
    case push
    case modal
    /// Pop transitions are only valid when navigating back to an ancestor in the back stack.
    case pop

    /// A textual representation of the transition, used by the
    /// `prettyPrintPath` method to produce human‑readable output.
    public var description: String {
        switch self {
        case .push: return "push"
        case .modal: return "modal"
        case .pop: return "pop"
        }
    }
}
