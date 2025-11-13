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
- ⚡ **Event-Driven**: Non-blocking navigation that handles back gestures and user interaction naturally
- 🎯 **Predictable**: Declarative navigation graph definitions
- 🔍 **Debuggable**: Comprehensive logging and graph visualization tools
- 🧩 **Extensible**: Pluggable node presentation handlers for custom UI integration
- 🔁 **Headless Processing**: Data transformation nodes without UI presentation

## Architecture Overview

NavigationGraph is built around several core components:

### Core Components

1. **NavNode**: Protocol representing a navigation destination
2. **ScreenNode**: Concrete node implementation for UI-based screens
3. **HeadlessNode**: Node for data processing without UI presentation
4. **NavigationGraph**: Container for nodes and their connecting edges
5. **Edge**: Defines transitions between nodes with type-safe data transformation
6. **NavigationController**: Event-driven manager for UIKit navigation based on the graph
7. **NodeRegistry**: Dependency injection container for nodes
8. **NavSubgraph**: Nested navigation flows with entry and exit points

### Navigation Flow

```
[Screen Node] --[Edge]--> [Headless Node] --[Edge]--> [Screen Node]
     |                         |                          |
 InputType               OutputType                 InputType
```

Each node defines:
- **InputType**: Data required to present the screen or process
- **OutputType**: Data produced when the screen completes or processing finishes

Edges define:
- **Predicate**: Condition for taking this path
- **Transform**: Function to convert OutputType to next InputType
- **Transition**: UIKit transition type (.push, .modal, .pop, etc.)

The NavigationController uses an **event-driven architecture** that:
- Listens for completion callbacks from view controllers
- Handles back button taps and swipe gestures automatically
- Maintains an internal stack that mirrors UIKit's navigation state
- Supports non-blocking navigation allowing natural user interaction

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
- `.clearStackAndSet`: Clear the entire navigation stack and set a new root
- `.none`: No UI transition (used when dismissal is automatic, e.g., alert controllers)

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

Create nested navigation flows using subgraphs. Subgraphs require both an entry node (where navigation begins) and an exit node (where navigation completes):

```swift
// Create a sign-in subgraph
let signInGraph = NavigationGraph()
let exitNode = HeadlessNode<Void, Void>() // Headless exit node

signInGraph.addNode(signInHome)
signInGraph.addNode(forgotPassword)
signInGraph.addNode(exitNode)

signInGraph.addEdge(Edge(from: signInHome, to: forgotPassword, transition: .push))
signInGraph.addEdge(Edge(from: forgotPassword, to: exitNode, transition: .none))

// Wrap as a subgraph with entry and exit nodes
let signInSubgraph = NavSubgraph(
    id: "signInFlow",
    graph: signInGraph,
    entry: signInHome,
    exit: exitNode
)

// Add to main graph
mainGraph.addSubgraph(signInSubgraph)
```

### Headless Nodes

Process data or execute logic without presenting UI using headless nodes:

```swift
// Create a headless node for data processing
let validationNode = HeadlessNode<UserData, ValidationResult>(
    id: "validator",
    transform: { userData in
        // Perform validation logic
        return validate(userData)
    }
)

graph.addNode(validationNode)
graph.addEdge(Edge(
    from: inputNode,
    to: validationNode,
    transition: .none,
    transform: { input in input }
))

// Navigate to different nodes based on validation result
graph.addEdge(Edge(
    from: validationNode,
    to: successNode,
    transition: .push,
    predicate: { result in result.isValid }
))
```

Headless nodes are useful for:
- Data transformation between screens
- Validation logic
- API calls or async operations
- Conditional routing decisions
- Exit nodes for subgraphs

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

### Custom Node Presentation

Extend the navigation system with custom presentation handlers:

```swift
struct CustomNodeHandler: NodePresentationHandler {
    func canHandle(nodeType: Any.Type) -> Bool {
        // Return true if this handler can present the node type
        return nodeType is MyCustomNode.Type
    }
    
    func makeViewController(
        for node: AnyNavNode,
        input: Any,
        onComplete: @escaping (Any) -> Void
    ) -> UIViewController? {
        // Create and configure your custom view controller
        let vc = MyCustomViewController()
        vc.onComplete = onComplete
        return vc
    }
}

// Register custom handler with NavigationController
let navController = NavigationController(
    graph: graph,
    navigationController: UINavigationController(),
    handlers: [CustomNodeHandler(), DefaultUIKitNodeHandler()]
)
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
- Sign-in subgraph with forgot password flow and exit nodes
- Gender selection with conditional branching
- Photo selection with modal presentations
- Map integration
- Error handling with alert controllers (using `.none` transition)
- Nested subgraphs (photo selector within larger flows)
- Headless nodes for flow control

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
- `ScreenNode<Input, Output>`: Concrete node implementation for UI screens
- `HeadlessNode<Input, Output>`: Node for data processing without UI
- `Edge<From, To>`: Type-safe navigation edge
- `NavigationController`: Event-driven UIKit navigation manager
- `NodeRegistry`: Dependency injection container
- `NavSubgraph<Entry, Exit>`: Nested navigation flow with entry and exit nodes

### Protocols

- `NavigableViewController`: UIViewController extension for navigation
- `ViewControllerProviding`: Factory protocol for creating view controllers
- `NavSubgraphProtocol`: Protocol for nested navigation graphs
- `NodePresentationHandler`: Protocol for custom node presentation logic

### Key Methods

- `NavigationGraph.addNode(_:)`: Register a node
- `NavigationGraph.addSubgraph(_:)`: Register a subgraph as a node
- `NavigationGraph.addEdge(_:)`: Define navigation edge
- `NavigationController.start(at:with:)`: Begin navigation
- `NodeRegistry.register(_:)`: Register node for DI
- `NodeRegistry.registerSubgraph(_:)`: Register subgraph for DI

### Transition Types

- `TransitionType.push`: Standard push navigation
- `TransitionType.modal`: Modal presentation
- `TransitionType.pop`: Pop current screen
- `TransitionType.popTo(Int)`: Pop to specific stack index
- `TransitionType.dismiss`: Dismiss modal
- `TransitionType.clearStackAndSet`: Clear stack and set new root
- `TransitionType.none`: No UI transition (automatic dismissal)

## Future Enhancements

The codebase includes TODO comments for potential improvements:

- Deep linking support
- Navigation stack rehydration
- Codable graph definitions
- SwiftUI integration
- Enhanced DSL for graph definition
- Priority-based edge selection