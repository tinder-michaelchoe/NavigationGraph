//
//  PhotosPickerVIewController.swift
//  NavigationGraph
//
//  Created by Michael Choe on 8/1/25.
//

import PhotosUI
import UIKit

final class PhotosSelectorNode: NavNode, ViewControllerProviding {

    typealias InputType = Void
    typealias OutputType = [PHPickerResult]

    let viewControllerFactory: (()) -> PhotosPickerViewController = { _ in
        return PhotosPickerViewController()
    }
}

class PhotosPickerViewController: UIViewController, NavigableViewController {

    enum PickerResult {
        case didPick(results: [PHPickerResult])
    }

    var onComplete: ((_ results: [PHPickerResult]) -> Void)?

    private lazy var pickerVC: PHPickerViewController = {
        let picker = PHPickerViewController(configuration: .init(photoLibrary: .shared()))
        picker.delegate = self
        return picker
    }()

    init() {
        super.init(nibName: nil, bundle: nil)

        view.addAutolayoutSubview(pickerVC.view)

        installConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func installConstraints() {
        view.addConstraints([
            pickerVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pickerVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pickerVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            pickerVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

extension PhotosPickerViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        print("Did Finish PIcking: \(results)")
        onComplete?(results)
    }
}
