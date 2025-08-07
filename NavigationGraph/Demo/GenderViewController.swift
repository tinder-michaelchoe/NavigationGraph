//
//  GenderViewController.swift
//  NavigationGraph
//
//  Created by Michael Choe on 7/31/25.
//

import Combine
import SwiftUI
import UIKit

final class GenderNode: NavNode, ViewControllerProviding {

    typealias InputType = GenderViewController.InitialState?
    typealias OutputType = GenderViewController.GenderResult

    let viewControllerFactory: (GenderViewController.InitialState?) -> GenderViewController = { initialState in
        return GenderViewController(initialState: initialState)
    }
}

class GenderViewController: UIViewController, NavigableViewController {

    enum GenderResult: Equatable {
        case beyondBinary
        case error(String, String)
        case learnMore
        case next(String)
    }

    struct InitialState {
        let beyondBinaryDetail: String?
        let gender: String
        let name: String?
    }

    var onComplete: ((GenderResult) -> Void)?

    private var cancellables = Set<AnyCancellable>()
    private lazy var hostedView = UIHostingController(rootView: GenderView(viewState: viewState))
    private lazy var viewState = GenderViewState(initialState: initialState)
    private let initialState: InitialState?

    init(initialState: InitialState? = nil) {
        self.initialState = initialState
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        hostedView.rootView.viewState.$didPressBeyondBinary
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                onComplete?(.beyondBinary)
            }
            .store(in: &cancellables)

        hostedView.rootView.viewState.$didPressNext
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                if let selectedGender = viewState.selectedGender {
                    onComplete?(.next(selectedGender))
                } else {
                    onComplete?(.error("Nothing Selected", "Please select an option for what you identify as."))
                }
            }
            .store(in: &cancellables)

        hostedView.rootView.viewState.$didPressLearnMore
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                onComplete?(.learnMore)
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

class GenderViewState: ObservableObject {
    @Published var didPressBeyondBinary: Int = 0
    @Published var didPressNext: Int = 0
    @Published var didPressLearnMore: Int = 0

    let beyondBinaryDetail: String?
    @Published var selectedGender: String?

    init(initialState: GenderViewController.InitialState?) {
        self.beyondBinaryDetail = initialState?.beyondBinaryDetail
        self.didPressBeyondBinary = 0
        self.didPressNext = 0
        self.didPressLearnMore = 0
        self.selectedGender = initialState?.gender ?? nil
    }
}

struct GenderView: View {

    @ObservedObject var viewState: GenderViewState

    @State private var name: String = ""

    let genderOptions = ["Man", "Woman", "Beyond Binary"]

    var body: some View {
        VStack {
            Spacer(minLength: 80.0)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Your Name")
                        .font(.headline)
                        .padding(.horizontal)
                    // Name Field
                    TextField("Enter your name", text: $name)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    Spacer()
                    // Gender Prompt
                    Text("Your gender")
                        .font(.headline)
                        .padding(.horizontal)

                    // Gender Pills
                    VStack(spacing: 12) {
                        ForEach(genderOptions, id: \.self) { gender in
                            Button(action: {
                                viewState.selectedGender = gender
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(gender)
                                            .fontWeight(.medium)
                                            .foregroundStyle(Color.gray)
                                        GenderTextView(beyondBinaryDetails: viewState.beyondBinaryDetail, gender: gender)
                                    }
                                    Spacer()
                                    if viewState.selectedGender == gender {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color(red: 139/255, green: 0, blue: 0))
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal)
                                .background(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(
                                            viewState.selectedGender == gender
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

                    // Add More Link
                    Button(action: {
                        self.viewState.didPressLearnMore += 1
                    }) {
                        Text("Learn why Amora asks for this information")
                            .font(.footnote)
                            .underline()
                            .foregroundColor(Color(red: 139/255, green: 0, blue: 0))
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
                .padding(.top, 32)
                .padding(.bottom, 80) // space for bottom button
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: {
                    self.viewState.didPressNext += 1
                }) {
                    Text("Next")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(red: 139/255, green: 0, blue: 0))
                        .cornerRadius(30)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
                .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
                .padding(.bottom, 48)
            }
        }
        .onChange(of: viewState.selectedGender) { _, _ in
            if viewState.selectedGender == "Beyond Binary" {
                self.viewState.didPressBeyondBinary += 1
            }
        }
    }
}

private struct GenderTextView: View {

    let beyondBinaryDetails: String?
    let gender: String

    var body: some View {
        if let beyondBinaryDetails, gender == "Beyond Binary" {
            Text(beyondBinaryDetails)
                .fontWeight(.medium)
                .foregroundStyle(Color.gray)
                .dynamicTypeSize(.xSmall)
        } else {
            VStack {}
        }
    }
}
