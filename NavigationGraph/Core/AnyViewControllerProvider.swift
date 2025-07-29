import UIKit

/*
final class AnyViewControllerProvider {
    private let _makeViewController: (Any) -> (UIViewController & NavigableViewController)?

    init<Provider: ViewControllerProviding>(_ provider: Provider) {
        _makeViewController = { input in
            guard let typedInput = input as? Provider.Input else { return nil }
            return provider.viewControllerFactory?(typedInput)
        }
    }

    func makeViewController(with input: Any) -> (UIViewController & NavigableViewController)? {
        _makeViewController(input)
    }
}
*/
