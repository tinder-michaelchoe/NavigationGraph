//
//  ExampleUIKitNavigation.swift
//

import UIKit

struct User {
    let name: String = "Frank"
}

final class AppCoordinator {

    private let uiNavigationController: UINavigationController
    private let navController: NavigationController

    init() {
        self.uiNavigationController = UINavigationController()

        let nodeRegistry = NodeRegistry()
        nodeRegistry.register(WelcomeNode())
        nodeRegistry.register(OneShotAlertNode())
        nodeRegistry.register(SignInHomeNode())
        nodeRegistry.register(ForgotPasswordNode())
        nodeRegistry.register(GenderNode())
        nodeRegistry.register(SafetyNode())
        nodeRegistry.register(BeyondBinaryNode())
        nodeRegistry.register(GenderLearnMoreNode())
        nodeRegistry.register(PhotosNode())
        nodeRegistry.register(PhotosSelectorNode())
        nodeRegistry.register(MapNode())
        nodeRegistry.register(EndNode())

        let variant = DemoGraphVariant1(registry: nodeRegistry)

        // Uncomment to see other variant. Not as complete or robust.
        //let variant = DemoGraphVariant2(registry: nodeRegistry)

        self.navController = NavigationController(
            graph: variant.graph,
            navigationController: uiNavigationController
        )
    }

    func start(in window: UIWindow) {
        window.rootViewController = uiNavigationController
        window.makeKeyAndVisible()
        navController.start(at: WelcomeNode(), with: ())
    }
}
