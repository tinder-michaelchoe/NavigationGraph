//
//  ForgotPasswordViewController.swift
//  NavigationGraph
//
//  Created by mexicanpizza on 7/29/25.
//

import Combine
import SwiftUI
import UIKit

final class ForgotPasswordNode: NavNode, ViewControllerProviding {

    typealias InputType = String?
    typealias OutputType = Void

    let viewControllerFactory: (String?) -> ForgotPasswordViewController = { possibleEmail in
        return ForgotPasswordViewController(initialEmailAddress: possibleEmail)
    }
}

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

    @State private var email: String = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Title
            Text("Forgot Password")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.top)

            // Description
            Text("Enter the email address you used to create your account and we'll send you a password reset link.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Email Input
            TextField("Email Address", text: $viewState.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)

            // Submit Button
            Button(action: {
                self.viewState.didPressNext += 1
            }) {
                Text("Send Reset Link")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 139/255, green: 0, blue: 0)) // Dark red
                    .cornerRadius(12)
                    .padding(.horizontal)
            }

            Spacer()
        }
    }
}
