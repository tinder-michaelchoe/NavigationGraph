//
//  SigninViewController.swift
//  NavigationGraph
//
//  Created by mexicanpizza on 7/29/25.
//

import Combine
import SwiftUI
import UIKit

final class SignInHomeNode: NavNode, ViewControllerProviding {

    typealias InputType = Void
    typealias OutputType = SignInViewController.SignInResult

    let viewControllerFactory: (()) -> SignInViewController = { _ in
        return SignInViewController()
    }
}

class SignInViewController: UIViewController, NavigableViewController {

    enum SignInResult: Equatable {
        case signIn
        case forgotPassword(String?)
    }

    var onComplete: ((SignInResult) -> Void)?

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

        viewState.$didPressForgotPassword
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                onComplete?(.forgotPassword(viewState.partialEmail))
            }
            .store(in: &cancellables)

        viewState.$didPressSignIn
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

class SigninViewState: ObservableObject {
    @Published var didPressForgotPassword: Int = 0
    @Published var didPressSignIn: Int = 0

    var partialEmail: String?
}

struct SigninView: View {

    @ObservedObject var viewState: SigninViewState

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isPasswordHidden: Bool = true

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Title
            Text("Sign In to Amora")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            // Email Field
            TextField("Email Address", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)

            // Password Field with show/hide toggle
            ZStack(alignment: .trailing) {
                if isPasswordHidden {
                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        .padding(.horizontal)
                } else {
                    TextField("Password", text: $password)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        .padding(.horizontal)
                }

                Button(action: {
                    isPasswordHidden.toggle()
                }) {
                    Image(systemName: self.isPasswordHidden ? "eye.slash" : "eye")
                        .foregroundColor(.gray)
                        .padding(.trailing, 35)
                }
            }

            Spacer()

            // Submit Button
            Button(action: {
                self.viewState.didPressSignIn += 1
            }) {
                Text("Sign In")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: 360)
                    .background(Color(red: 139/255, green: 0, blue: 0)) // Dark red
                    .cornerRadius(12)
                    .padding(.horizontal)
            }

            // Forgot Password
            Button(action: {
                self.viewState.partialEmail = self.email
                self.viewState.didPressForgotPassword += 1
            }) {
                Text("Forgot Password?")
                    .font(.subheadline)
                    .foregroundColor(Color(red: 139/255, green: 0, blue: 0)) // Dark red
            }
            Spacer()
        }
        .padding(.top, 40)
    }
}
