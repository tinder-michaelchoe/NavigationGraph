//
//  ForgotPasswordViewController.swift
//  NavigationGraph
//
//  Created by mexicanpizza on 7/29/25.
//

import Combine
import SwiftUI
import UIKit

class ForgotPasswordViewController: UIViewController, NavigableViewController {
    
    var onComplete: ((Any) -> Void)?
    
    private var cancellables = Set<AnyCancellable>()
    private lazy var hostedView = UIHostingController(rootView: ForgotPasswordView(viewState: viewState))
    private var initialEmailAddress: String?
    private let viewState: ForgotPasswordViewState
    
    init(initialEmailAddress: String?) {
        self.initialEmailAddress = initialEmailAddress
        self.viewState = ForgotPasswordViewState()
        self.viewState.emailAddress = initialEmailAddress ?? ""
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
                onComplete?(())
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

class ForgotPasswordViewState: ObservableObject {
    @Published var didPressNext: Int = 0
    @Published var emailAddress: String = ""
}

struct ForgotPasswordView: View {
    
    @ObservedObject var viewState: ForgotPasswordViewState
    
    var body: some View {
        VStack(spacing: 48.0) {
            Text("Forgot Password")
                .font(.largeTitle)
                .multilineTextAlignment(.center)
            TextField("Email Address", text: $viewState.emailAddress)
                //.placeholder(Text("Enter your email address"))
        }
        .ignoresSafeArea()
        .background(Color.mint.frame(width: .greatestFiniteMagnitude, height: .greatestFiniteMagnitude))
    }
    
}
