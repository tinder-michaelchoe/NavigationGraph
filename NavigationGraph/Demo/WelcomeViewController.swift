//
//  WelcomeViewController.swift
//  NavigationGraph
//
//  Created by mexicanpizza on 7/29/25.
//

import Combine
import SwiftUI
import UIKit

final class WelcomeNode: NavNode, ViewControllerProviding {

    typealias InputType = Void
    typealias OutputType = WelcomeViewController.WelcomeResult

    let viewControllerFactory: (()) -> WelcomeViewController = { _ in
        return WelcomeViewController()
    }
}

class WelcomeViewController: UIViewController, NavigableViewController {

    enum WelcomeResult {
        case logo
        case next
        case signIn
    }

    var onComplete: ((WelcomeResult) -> Void)?

    private var cancellables = Set<AnyCancellable>()
    private lazy var hostedView = UIHostingController(rootView: WelcomeView(viewState: viewState))
    private let viewState = WelcomeViewState()

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        hostedView.rootView.viewState.$didPressLogo
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                onComplete?(.logo)
            }
            .store(in: &cancellables)

        hostedView.rootView.viewState.$didPressNext
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                onComplete?(.next)
            }
            .store(in: &cancellables)

        hostedView.rootView.viewState.$didPressSignIn
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                onComplete?(.signIn)
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

class WelcomeViewState: ObservableObject {
    @Published var didPressLogo: Int = 0
    @Published var didPressNext: Int = 0
    @Published var didPressSignIn: Int = 0
}

struct WelcomeView: View {

    @ObservedObject var viewState: WelcomeViewState

    var body: some View {
        ZStack {
            // Background Image
            Image("welcome-background") // Replace with actual asset name
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // Dark overlay for text readability
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // App Logo
                Button {
                    self.viewState.didPressLogo += 1
                } label: {
                    Image("amora-logo") // Replace with actual asset name
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                }


                // Tagline
                Text("Meet Travelers. Make Memories.")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                // CTA Button
                Button(action: {
                    self.viewState.didPressNext += 1
                }) {
                    Text("Start Your Journey")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: 360)
                        .background(Color(red: 139/255, green: 0, blue: 0)) // Dark red
                        .cornerRadius(12)
                        .padding(.horizontal, 32)
                }
                Button(action: {
                    self.viewState.didPressSignIn += 1
                }) {
                    Text("Sign in")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: 300.0)
                }
                Spacer()
            }
        }
    }
}
