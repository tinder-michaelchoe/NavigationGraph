//
//  SafetyViewController.swift
//  NavigationGraph
//
//  Created by Michael Choe on 8/5/25.
//

import Combine
import SwiftUI
import UIKit

final class SafetyNode: NavNode, ViewControllerProviding {

    typealias InputType = Void
    typealias OutputType = Void

    let viewControllerFactory: (()) -> SafetyViewController = { _ in
        return SafetyViewController()
    }
}

class SafetyViewController: UIViewController, NavigableViewController {

    enum SafetyResult {
        case next
    }

    var onComplete: ((SafetyResult) -> Void)?

    private var cancellables = Set<AnyCancellable>()
    private lazy var hostedView = UIHostingController(rootView: SafetyView(viewState: viewState))
    private let viewState = SafetyViewState()

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
                onComplete?(.next)
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

class SafetyViewState: ObservableObject {
    @Published var didPressNext: Int = 0
}

struct SafetyView: View {

    let viewState: SafetyViewState

    var body: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 40.0)
            // Header Gradient Circle Icon
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [.pink, Color(red: 139/255, green: 0, blue: 0), .purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 120, height: 120)
                    .shadow(radius: 12)

                Image(systemName: "shield.lefthalf.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .foregroundColor(.white)
            }
            .padding(.top)

            // Title
            Text("Your Safety Comes First")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            // Subtitle
            Text("We’ve built protections just for LGBTQ+ users, so you can explore confidently and authentically.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Feature Highlights
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "eye.slash", title: "Discreet Browsing", description: "Hide your profile in countries where it's unsafe to be out.")
                FeatureRow(icon: "flag", title: "Instant Reporting", description: "Flag harassment or discrimination and our team will respond fast.")
                FeatureRow(icon: "person.crop.circle.badge.checkmark", title: "Identity Options", description: "Express your gender, pronouns, and preferences freely.")
            }
            .padding(.horizontal)

            Spacer()
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: {
                self.viewState.didPressNext += 1
            }) {
                Text("Got it, let’s go")
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
        //.navigationBarBackButtonHidden(true)
    }
}

// MARK: - Subcomponent for Feature Rows
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .foregroundColor(Color(red: 139/255, green: 0, blue: 0))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }
}
