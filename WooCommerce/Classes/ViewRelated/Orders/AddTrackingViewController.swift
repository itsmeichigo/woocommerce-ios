//
//  AddTrackingViewController.swift
//  WooCommerce
//
//  Created by Cesar Tardaguila on 21/3/2019.
//  Copyright © 2019 Automattic. All rights reserved.
//

import UIKit

final class AddTrackingViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigation()
        // Do any additional setup after loading the view.
    }


    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}


private extension AddTrackingViewController {
    func configureNavigation() {
        configureTitle()
        configureDismissButton()
        configureAddButton()
    }

    func configureTitle() {
        title = NSLocalizedString("Add Tracking",
            comment: "Add tracking screen - title.")
    }

    func configureDismissButton() {
        let dismissButtonTitle = NSLocalizedString("Dismiss",
                                                   comment: "Add a note screen - button title for closing the view")
        let leftBarButton = UIBarButtonItem(title: dismissButtonTitle,
                                            style: .plain,
                                            target: self,
                                            action: #selector(dismissButtonTapped))
        leftBarButton.tintColor = .white
        navigationItem.setLeftBarButton(leftBarButton, animated: false)
    }

    func configureAddButton() {
        let addButtonTitle = NSLocalizedString("Add",
                                               comment: "Add tracking screen - button title to add a tracking")
        let rightBarButton = UIBarButtonItem(title: addButtonTitle,
                                             style: .done,
                                             target: self,
                                             action: #selector(addButtonTapped))
        rightBarButton.tintColor = .white
        navigationItem.setRightBarButton(rightBarButton, animated: false)
        navigationItem.rightBarButtonItem?.isEnabled = false
    }

    @objc func dismissButtonTapped() {
        dismiss(animated: true, completion: nil)
    }

    @objc func addButtonTapped() {
        print("=== add===")
    }
}
