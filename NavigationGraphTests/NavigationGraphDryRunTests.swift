@testable import NavigationGraph
import Testing

// Dummy graph builder for tests
func makeTestGraph() -> NavigationGraph {
    let home = ScreenNode<Void, Void>("home")
    let profile = ScreenNode<Bool, Void>("profile")
    let settings = ScreenNode<Void, Void>("settings")

    let graph = NavigationGraph()
    graph.addNode(home)
    graph.addNode(profile)
    graph.addNode(settings)
    graph.addEdge(
        Edge(from: home, to: profile, transition: .push) { _ in false }
    )
    graph.addEdge(
        Edge(from: profile, to: settings, transition: .modal, predicate: { true }) { _ in () }
    )
    return graph
}

@Suite("NavigationGraph dry run navigation tests")
@MainActor
struct NavigationDryRunTests {
    
    @Test func testHappyPath() async throws {
        let graph = makeTestGraph()
        let steps = try graph.dryRun(
            from: "home",
            initialInput: (),
            outputProvider: { nodeId, _ in
                switch nodeId {
                case "profile": return true
                default: return false
                }
            },
            stopAt: { $0 == "settings" }
        )
        #expect(steps.last?.to == "settings")
        #expect(steps.count == 2)
    }

    @MainActor
    @Test func testUnreachableNodeDetection() async throws {
        let graph = makeTestGraph()
        let unreachable = graph.unreachableNodes()
        // In this simple graph, all nodes are reachable except possibly the start node.
        #expect(unreachable.contains("home") == false)
    }

    @MainActor
    @Test func testCycleDetection() async throws {
        let g = NavigationGraph()
        let a = ScreenNode<Void, Void>("a")
        let b = ScreenNode<Void, Void>("b")
        g.addNode(a)
        g.addNode(b)
        g.addEdge(Edge(from: a, to: b, transition: .push) { _ in () })
        g.addEdge(Edge(from: b, to: a, transition: .push) { _ in () })
        #expect(g.containsCycle() == true)
    }
    
    @MainActor
    @Test func testPathAssertions() async throws {
        let graph = makeTestGraph()
        let result = try graph.assertPath(from: "home", to: "settings", expectedTransitions: [.push, .modal])
        #expect(result != nil)
    }
}
