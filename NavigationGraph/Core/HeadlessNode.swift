//
//  HeadlessNOde.swift
//  NavigationGraph
//
//  Created by mexicanpizza on 7/30/25.
//

final class HeadlessNode<Input, Output>: NavNode {
    typealias InputType = Input
    typealias OutputType = Output
    
    var id: String
    
    init(id: String) {
        self.id = id
    }
}
