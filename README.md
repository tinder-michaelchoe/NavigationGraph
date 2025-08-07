# NavigationGraph

A powerful, type-safe navigation framework for iOS applications that uses graph-based navigation patterns. NavigationGraph allows you to define your app's navigation flow as a directed graph with nodes representing screens and edges representing transitions between them.

## Table of Contents

- [Features](#features)
- [Architecture Overview](#architecture-overview)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
- [Advanced Features](#advanced-features)
- [Examples](#examples)
- [Testing](#testing)

## Features

- 🔒 **Type Safety**: Compile-time type checking for navigation data flow
- 📱 **UIKit Integration**: Seamless integration with UIKit navigation patterns
- 🔄 **Complex Flows**: Support for conditional navigation, subgraphs, and nested flows
- 🧪 **Testable**: Built-in testing utilities for validating navigation flows
- ⚡ **Event-Driven**: Non-blocking navigation that supports user interaction
- 🎯 **Predictable**: Declarative navigation graph definitions
- 🔍 **Debuggable**: Comprehensive logging and graph visualization tools

## Architecture Overview

NavigationGraph is built around several core components:

### Core Components

1. **NavNode**: Protocol representing a navigation destination
2. **NavigationGraph**: Container for nodes and their connecting edges
3. **Edge**: Defines transitions between nodes with type-safe data transformation
4. **NavigationController**: Manages UIKit navigation based on the graph
5. **NodeRegistry**: Dependency injection container for nodes

### Navigation Flow

```
[Start Node] --[Edge]--> [Destination Node] --[Edge]--> [End Node]
     |                         |                          |
 InputType               OutputType                 InputType
```

Each node defines:
- **InputType**: Data required to present the screen
- **OutputType**: Data produced when the screen completes

Edges define:
- **Predicate**: Condition for taking this path
- **Transform**: Function to convert OutputType to next InputType
- **Transition**: UIKit transition type (.push, .modal, .pop, etc.)

## Requirements

- iOS 18.0+
- Xcode 16.0+
- Swift 6.0+

## Quick Start

### 1. Define Your Nodes

```swift
import NavigationGraph

// Simple node with no input/output
final class WelcomeNode: NavNode, ViewControllerProviding {
    typealias InputType = Void
    typealias OutputType = WelcomeResult
    
    enum WelcomeResult {
        case next
        case signIn
    }
    
    let viewControllerFactory: (Void) -> WelcomeViewController = { _ in
        WelcomeViewController()
    }
}

// Node that requires user input
final class ProfileNode: NavNode, ViewControllerProviding {
    typealias InputType = User
    typealias OutputType = Bool
    
    let viewControllerFactory: (User) -> ProfileViewController = { user in
        ProfileViewController(user: user)
    }
}
```

### 2. Create View Controllers

```swift
class WelcomeViewController: UIViewController, NavigableViewController {
    typealias CompletionType = WelcomeNode.OutputType
    
    var onComplete: ((CompletionType) -> Void)?
    
    @IBAction func nextTapped() {
        onComplete?(.next)
    }
    
    @IBAction func signInTapped() {
        onComplete?(.signIn)
    }
}
```

### 3. Build Your Navigation Graph

```swift
func createNavigationGraph() -> NavigationGraph {
    let graph = NavigationGraph()
    
    // Register nodes
    let welcome = WelcomeNode()
    let profile = ProfileNode()
    let signIn = SignInNode()
    
    graph.addNode(welcome)
    graph.addNode(profile)
    graph.addNode(signIn)
    
    // Define edges
    graph.addEdge(Edge(
        from: welcome,
        to: profile,
        transition: .push,
        predicate: { $0 == .next },
        transform: { _ in User(name: "Default") }
    ))
    
    graph.addEdge(Edge(
        from: welcome,
        to: signIn,
        transition: .push,
        predicate: { $0 == .signIn }
    ))
    
    return graph
}
```

### 4. Set Up Navigation

```swift
class AppCoordinator {
    private let uiNavigationController = UINavigationController()
    private let navController: NavigationController
    
    init() {
        let graph = createNavigationGraph()
        self.navController = NavigationController(
            graph: graph,
            navigationController: uiNavigationController
        )
    }
    
    func start(in window: UIWindow) {
        window.rootViewController = uiNavigationController
        window.makeKeyAndVisible()
        navController.start(at: WelcomeNode(), with: ())
    }
}
```

## Core Concepts

### Nodes

Nodes represent screens or destinations in your app. They conform to the `NavNode` protocol:

```swift
public protocol NavNode: AnyObject {
    associatedtype InputType
    associatedtype OutputType
    var id: String { get }
}
```

### Edges

Edges define how to navigate between nodes:

```swift
let edge = Edge(
    from: sourceNode,
    to: destinationNode,
    transition: .push,
    predicate: { output in output.isValid },
    transform: { output in DestinationInput(data: output.data) }
)
```

### Transition Types

- `.push`: Standard navigation controller push
- `.modal`: Present modally
- `.pop`: Pop back to previous screen
- `.popTo(Int)`: Pop to specific index in stack
- `.dismiss`: Dismiss modal presentation
- `.none`: No visual transition (for data-only navigation)

### Node Registry

The NodeRegistry provides dependency injection for nodes:

```swift
let registry = NodeRegistry()
registry.register(WelcomeNode())
registry.register(ProfileNode())

let welcomeNode = registry.resolve(WelcomeNode.self)
```

## Advanced Features

### Subgraphs

Create nested navigation flows using subgraphs:

```swift
// Create a sign-in subgraph
let signInGraph = NavigationGraph()
signInGraph.addNode(signInHome)
signInGraph.addNode(forgotPassword)
signInGraph.addEdge(Edge(from: signInHome, to: forgotPassword, transition: .push))

// Wrap as a subgraph
let signInSubgraph = NavSubgraph(
    id: "signInFlow",
    graph: signInGraph,
    start: signInHome
)

// Add to main graph
mainGraph.addSubgraph(signInSubgraph)
```

### Conditional Navigation

Use predicates to create branching flows:

```swift
graph.addEdge(Edge(
    from: userForm,
    to: teenageFlow,
    transition: .push,
    predicate: { user in user.age < 18 }
))

graph.addEdge(Edge(
    from: userForm,
    to: adultFlow,
    transition: .push,
    predicate: { user in user.age >= 18 }
))
```

### Error Handling

Navigate to error screens based on conditions:

```swift
graph.addEdge(Edge(
    from: dataEntry,
    to: errorAlert,
    transition: .modal,
    predicate: { result in 
        if case .error = result { return true }
        return false
    },
    transform: { result in
        if case .error(let message) = result {
            return ("Error", message)
        }
        return ("Error", "Unknown error")
    }
))
```

## Examples

### Simple Linear Flow

```swift
Welcome -> Profile -> Settings -> End
```

### Branching Flow with Subgraphs

```swift
Welcome -> [Sign In Subgraph] -> End
       \-> [Registration Subgraph] -> Profile -> End
```

### Modal Flows

```swift
Main Flow -> Settings (modal) -> Advanced Settings
                             \-> Reset Confirmation (modal)
```

The demo app included in this project shows a comprehensive example with:
- Welcome screen with multiple paths
- Sign-in subgraph with forgot password flow
- Gender selection with conditional branching
- Photo selection with modal presentations
- Map integration
- Error handling with alerts

## Testing

NavigationGraph includes powerful testing utilities:

### Dry Run Testing

Test navigation flows without UI:

```swift
let steps = try graph.dryRun(
    from: "welcome",
    initialInput: (),
    outputProvider: { nodeId, input in
        switch nodeId {
        case "profile": return .next
        case "settings": return .save
        default: return .cancel
        }
    },
    stopAt: { $0 == "end" }
)

XCTAssertEqual(steps.count, 3)
XCTAssertEqual(steps.last?.to, "end")
```

### Path Validation

Verify that paths exist between nodes:

```swift
try graph.assertPath(
    from: "start",
    to: "end",
    expectedTransitions: [.push, .modal, .dismiss, .push]
)
```

### Graph Analysis

Analyze your graph for issues:

```swift
// Find unreachable nodes
let unreachable = graph.unreachableNodes()

// Detect cycles
let hasCycles = graph.containsCycle()

// Visualize graph structure
print(graph.prettyPrintOutline(from: "welcome"))
```

### Example Test Output

```
NavigationGraph outline from welcome:
└─ welcome
   ├─ signInSubgraph
   │  ┌─ [Subgraph: signInSubgraph]
   │  │  ├─ SignInHomeNode
   │  │  │  └─ ForgotPasswordNode
   │  │  │     └─ OneShotAlertNode
   │  │  └──────────────
   └─ gender
      ├─ BeyondBinaryNode
      ├─ OneShotAlertNode
      └─ photosToMap
```

## API Reference

### Core Classes

- `NavigationGraph`: Main container for nodes and edges
- `NavNode`: Protocol for navigation destinations
- `Edge<From, To>`: Type-safe navigation edge
- `NavigationController`: UIKit navigation manager
- `NodeRegistry`: Dependency injection container

### Protocols

- `NavigableViewController`: UIViewController extension for navigation
- `ViewControllerProviding`: Factory protocol for creating view controllers
- `NavSubgraphProtocol`: Protocol for nested navigation graphs

### Key Methods

- `NavigationGraph.addNode(_:)`: Register a node
- `NavigationGraph.addEdge(_:)`: Define navigation edge
- `NavigationController.start(at:with:)`: Begin navigation
- `NodeRegistry.register(_:)`: Register node for DI

## Future Enhancements

The codebase includes TODO comments for potential improvements:

- Deep linking support
- Navigation stack rehydration
- Codable graph definitions
- SwiftUI integration
- Enhanced DSL for graph definition
- Priority-based edge selection