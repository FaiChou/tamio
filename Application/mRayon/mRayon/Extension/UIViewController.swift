//
//  UIViewController.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/4.
//

import UIKit

extension UIViewController {
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
