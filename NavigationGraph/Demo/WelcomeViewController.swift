//
//  WelcomeViewController.swift
//  NavigationGraph
//
//  Created by mexicanpizza on 7/29/25.
//

import Combine
import SwiftUI
import UIKit

class WelcomeViewController: UIViewController, NavigableViewController {
    
    enum WelcomeResult {
        case next
        case signIn
    }
    
    var onComplete: ((Any) -> Void)?
    
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
        
        hostedView.rootView.viewState.$didPressNext
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                onComplete?(WelcomeResult.next)
            }
            .store(in: &cancellables)
        
        hostedView.rootView.viewState.$didPressSignIn
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                onComplete?(WelcomeResult.signIn)
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
    @Published var didPressNext: Int = 0
    @Published var didPressSignIn: Int = 0
}

struct WelcomeView: View {
    
    @ObservedObject var viewState: WelcomeViewState
    
    var body: some View {
        VStack(spacing: 48.0) {
            Text("Welcome to NavigationGraph!")
                .font(.largeTitle)
                .multilineTextAlignment(.center)
            Button {
                self.viewState.didPressNext += 1
            } label: {
                Text("Let's Go!")
                    .font(.title2)
                    .padding(16.0)
                    .foregroundStyle(.white)
            }
            .background(
                RoundedRectangle(cornerSize: .init(width: 6.0, height: 6.0))
                    .background(Color.accentColor)
            )
            Button {
                self.viewState.didPressSignIn += 1
            } label: {
                Text("Sign In")
                    .font(.title2)
                    .padding(16.0)
                    .foregroundStyle(.white)
            }
            .background(
                RoundedRectangle(cornerSize: .init(width: 6.0, height: 6.0))
                    .background(Color.secondary)
            )
        }
        .ignoresSafeArea()
        .background(Color.mint.frame(width: .greatestFiniteMagnitude, height: .greatestFiniteMagnitude))
    }
}
