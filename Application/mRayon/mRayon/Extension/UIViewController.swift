//
//  UIViewController.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/4.
//

import UIKit

extension UIViewController {
    func hideKeyboardWhenTappedAround() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    var topbarHeight: CGFloat {
        (
            view
                .window?
                .windowScene?
                .statusBarManager?
                .statusBarFrame
                .height ?? 0.0
        ) + (
            navigationController?
                .navigationBar
                .frame
                .height ?? 0.0
        )
    }

    func present(next: UIViewController) {
        if let navigator = navigationController,
           !(next is UIAlertController),
           !(next is UIActivityViewController)
        {
            navigator.pushViewController(next, animated: true)
        } else {
            // The caller chooses the presentation style; the terminal asks
            // for .fullScreen on iPhone.
            next.modalTransitionStyle = .coverVertical
            present(next, animated: true, completion: nil)
        }
    }
}
