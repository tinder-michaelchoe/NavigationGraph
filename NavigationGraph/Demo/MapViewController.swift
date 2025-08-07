//
//  MapViewController.swift
//  NavigationGraph
//
//  Created by Michael Choe on 8/1/25.
//

import Combine
import MapKit
import SwiftUI
import UIKit

final class MapNode: NavNode, ViewControllerProviding {

    typealias InputType = Void
    typealias OutputType = MapViewController.MapResult

    let viewControllerFactory: (()) -> MapViewController = { _ in
        return MapViewController()
    }
}

class MapViewController: UIViewController, NavigableViewController {

    enum MapResult {
        case next
        case signIn
    }

    var onComplete: ((MapResult) -> Void)?

    private var cancellables = Set<AnyCancellable>()
    private lazy var hostedView = UIHostingController(rootView: MapView(viewState: viewState))
    private let viewState = MapViewState()

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

class MapViewState: ObservableObject {
    @Published var didPressNext: Int = 0
    @Published var didPressSignIn: Int = 0
}

struct MapView: View {

    @ObservedObject var viewState: MapViewState

    private let losAngeles = CLLocationCoordinate2D(latitude: 34.0906432, longitude: -118.3839645)

    @State private var distanceKm: Double = 25.0

    // Region state
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437),
        span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
    )

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 80.0)

            // Title
            Text("Distance Preference")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top)
                .multilineTextAlignment(.leading)

            // Map
            Map {
                Marker("Los Angeles", coordinate: losAngeles)
                    .tint(.orange)
                MapCircle(center: losAngeles, radius: distanceKm * 1000)
                    .stroke(Color.orange, lineWidth: 2)
                    .foregroundStyle(.blue.opacity(0.3))
                    .mapOverlayLevel(level: .aboveLabels)
            }

            // Slider and Label
            VStack(spacing: 8) {
                Text("Within \(Int(distanceKm)) km")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Slider(value: $distanceKm, in: 5...100, step: 1) {
                    Text("Distance")
                } minimumValueLabel: {
                    Text("5km")
                        .font(.caption)
                } maximumValueLabel: {
                    Text("100km")
                        .font(.caption)
                }
                .onChange(of: distanceKm, initial: false, { _, newValue in
                    updateRegion(for: newValue)
                })
            }
            .padding(.horizontal)
            Spacer()
        }
        .safeAreaInset(edge: .bottom) {
            // Bottom CTA Button
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
            .padding(.bottom, 16.0)
        }
        .onAppear {
            updateRegion(for: distanceKm)
        }
        .padding(.bottom, 26)
    }

    // Adjusts zoom based on distance
    private func updateRegion(for distanceKm: Double) {
        let latDelta = distanceKm / 111.0 // 1 degree ≈ 111km
        region = MKCoordinateRegion(
            center: losAngeles,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: latDelta)
        )
    }
}
