//
//  SigninViewController.swift
//  NavigationGraph
//
//  Created by mexicanpizza on 7/29/25.
//

import Combine
import SwiftUI
import UIKit

class SigninViewController: UIViewController, NavigableViewController {
    
    var onComplete: ((Any) -> Void)?
    
    private var cancellables = Set<AnyCancellable>()
    private lazy var hostedView = UIHostingController(rootView: SigninView(viewState: viewState))
    private let viewState = SigninViewState()
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        hostedView.rootView.viewState.$didPressForgotPassword
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                onComplete?(Bool.random() ? "test@email.com" : nil)
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

class SigninViewState: ObservableObject {
    @Published var didPressForgotPassword: Int = 0
}

struct SigninView: View {
    
    @ObservedObject var viewState: SigninViewState
    
    var body: some View {
        VStack(spacing: 48.0) {
            Text("Welcome back!")
                .font(.largeTitle)
                .multilineTextAlignment(.center)
            Button {
                self.viewState.didPressForgotPassword += 1
            } label: {
                Text("Forgot Password")
                    .font(.title2)
                    .padding(16.0)
                    .foregroundStyle(.white)
            }
            .background(
                RoundedRectangle(cornerSize: .init(width: 6.0, height: 6.0))
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.purple)
        .ignoresSafeArea()
    }
}
