//
//  EndViewController.swift
//  NavigationGraph
//
//  Created by Michael Choe on 8/2/25.
//

import Combine
import SwiftUI
import UIKit

final class EndNode: NavNode, ViewControllerProviding {

    typealias InputType = Void
    typealias OutputType = EndViewController.EndResult

    let viewControllerFactory: (()) -> EndViewController = { _ in
        return EndViewController()
    }
}

class EndViewController: UIViewController, NavigableViewController {

    enum EndResult: Equatable {
        case reset
    }

    var onComplete: ((EndResult) -> Void)?

    private var cancellables = Set<AnyCancellable>()
    private lazy var hostedView = UIHostingController(rootView: EndView(viewState: viewState))
    private let viewState = EndViewState()

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        hostedView.rootView.viewState.$didPressNext
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                onComplete?(.reset)
            }
            .store(in: &cancellables)

        view.addAutolayoutSubview(hostedView.view)

        installConstraints()
    }

    func installConstraints() {
        view.addConstraints([
            hostedView.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostedView.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostedView.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostedView.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

class EndViewState: ObservableObject {
    @Published var didPressNext: Int = 0
}

struct EndView: View {

    @ObservedObject var viewState: EndViewState

    var body: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 60)

            // Celebratory Illustration
            Image(systemName: "sparkles")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.white)
                .padding()
                .background(
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color(red: 139/255, green: 0, blue: 0), .pink]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                )
                .shadow(radius: 10)

            // Headline
            Text("You're Ready to Go!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            // Subtext
            Text("You’ve completed setup. Start meeting new people and exploring connections now.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Optional Fun Confetti Background Layer
            Spacer()

            // Start Over Button
            Button(action: {
                self.viewState.didPressNext += 1
            }) {
                Text("Start Over")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 139/255, green: 0, blue: 0))
                    .cornerRadius(30)
                    .padding(.horizontal)
            }
            .padding(.bottom, 26)
        }
        .padding(.horizontal)
        .navigationBarBackButtonHidden(true)
    }
}
