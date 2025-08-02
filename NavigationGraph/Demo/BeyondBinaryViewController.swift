//
//  BeyondBinaryViewController.swift
//  NavigationGraph
//
//  Created by Michael Choe on 7/31/25.
//

import Combine
import SwiftUI
import UIKit

final class BeyondBinaryNode: NavNode, ViewControllerProviding {

    typealias InputType = Void
    typealias OutputType = BeyondBinaryViewController.BeyondBinaryResult

    let viewControllerFactory: ((()) -> BeyondBinaryViewController)? = { _ in
        return BeyondBinaryViewController()
    }
}

class BeyondBinaryViewController: UIViewController, NavigableViewController {

    enum BeyondBinaryResult {
        case next(String?)
        case signIn
    }

    var onComplete: ((BeyondBinaryResult) -> Void)?

    private var cancellables = Set<AnyCancellable>()
    private lazy var hostedView = UIHostingController(rootView: BeyondBinaryView(viewState: viewState))
    private let viewState = BeyondBinaryViewState()

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
                onComplete?(.next(viewState.selectedIdentity))
            }
            .store(in: &cancellables)

        hostedView.rootView.viewState.$didPressSignIn
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                onComplete?(.signIn)
            }
            .store(in: &cancellables)

        hostedView.rootView.viewState.$selectedIdentity
            .dropFirst()
            .sink { [weak self] selectedIdentity in
                guard let self else { return }
                onComplete?(.next(selectedIdentity))
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

class BeyondBinaryViewState: ObservableObject {
    @Published var didPressNext: Int = 0
    @Published var didPressSignIn: Int = 0

    @Published var selectedIdentity: String?
}

struct BeyondBinaryView: View {

    @ObservedObject var viewState: BeyondBinaryViewState

    //@State private var selectedIdentity: String? = nil

    let genderIdentities = [
        "Non-binary",
        "Genderqueer",
        "Agender",
        "Two-Spirit",
        "Genderfluid",
        "Bigender"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
                .frame(height: 50)
            Text("Select Your Gender Identity")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal)
                .padding(.top, 32)

            VStack(spacing: 12) {
                ForEach(genderIdentities, id: \.self) { identity in
                    Button(action: {
                        viewState.selectedIdentity = identity
                    }) {
                        HStack {
                            if viewState.selectedIdentity == identity {
                                Text(identity)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color(red: 139/255, green: 0, blue: 0))
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color(red: 139/255, green: 0, blue: 0))
                            } else {
                                Text(identity)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.gray)
                                Spacer()
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal)
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(
                                    viewState.selectedIdentity == identity
                                    ? Color(red: 139/255, green: 0, blue: 0)
                                    : Color(.systemGray4),
                                    lineWidth: 2
                                )
                        )
                        .cornerRadius(25)
                    }
                    .padding(.horizontal)
                }
            }
            Spacer()
        }
        .navigationTitle("More Gender Options")
        .navigationBarTitleDisplayMode(.inline)
    }
}
