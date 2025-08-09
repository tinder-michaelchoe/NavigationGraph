//
//  PhotosViewController.swift
//  NavigationGraph
//
//  Created by Michael Choe on 8/1/25.
//

import Combine
import SwiftUI
import UIKit

final class PhotosNode: NavNode, ViewControllerProviding {

    typealias InputType = Void
    typealias OutputType = PhotosViewController.PhotosResult

    let viewControllerFactory: (()) -> PhotosViewController = { _ in
        return PhotosViewController()
    }
}

class PhotosViewController: UIViewController, NavigableViewController {

    enum PhotosResult {
        case next
        case photoSelector
    }

    var onComplete: ((PhotosResult) -> Void)?

    private var cancellables = Set<AnyCancellable>()
    private lazy var hostedView = UIHostingController(rootView: PhotosView(viewState: viewState))
    private let viewState = PhotosViewState()

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        viewState.$didPressNext
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                onComplete?(.next)
            }
            .store(in: &cancellables)

        viewState.$didPressPhotoSelector
            .dropFirst()
            .sink { [weak self] _ in
                guard let self else { return }
                onComplete?(.photoSelector)
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

class PhotosViewState: ObservableObject {
    @Published var didPressNext: Int = 0
    @Published var didPressSignIn: Int = 0
    @Published var didPressPhotoSelector: Int = 0
}

struct PhotosView: View {

    @ObservedObject var viewState: PhotosViewState

    @State private var selectedIndices: Set<Int> = []

    // Simulate a fixed number of photo slots
    private let totalSlots = 6
    private let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 16)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer(minLength: 80.0)
            // Header
            Text("Add Photos")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top)

            Text("Add at least 2 photos to help others get to know you.")
                .font(.body)
                .foregroundColor(.secondary)

            // Photo Grid
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(0..<totalSlots, id: \.self) { index in
                    ZStack {
                        Rectangle()
                            .fill(Color(.secondarySystemBackground))
                            .frame(height: 120)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedIndices.contains(index)
                                            ? Color(red: 139/255, green: 0, blue: 0)
                                            : Color(.systemGray4),
                                            lineWidth: 2)
                            )

                        VStack {
                            Image(systemName: selectedIndices.contains(index) ? "photo.fill" : "plus")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                                .foregroundColor(selectedIndices.contains(index)
                                                 ? Color(red: 139/255, green: 0, blue: 0)
                                                 : .gray)
                            Text(selectedIndices.contains(index) ? "Photo \(index + 1)" : "Add Photo")
                                .font(.footnote)
                                .foregroundColor(.gray)
                        }
                    }
                    .onTapGesture {
                        if selectedIndices.contains(index) {
                            selectedIndices.remove(index)
                        } else {
                            selectedIndices.insert(index)
                            viewState.didPressPhotoSelector += 1
                        }
                    }
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .safeAreaInset(edge: .bottom) {
            // Bottom CTA Button
            Button(action: {
                self.viewState.didPressNext += 1
            }) {
                Text("Continue")
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
        .padding(.horizontal)
        .navigationTitle("Photo Setup")
        .navigationBarTitleDisplayMode(.inline)
    }
}
