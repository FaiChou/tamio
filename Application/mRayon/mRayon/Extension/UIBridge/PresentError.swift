//
//  PresentError.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import RayonModule
import SPIndicator
import UIKit

extension UIBridge {
    static func presentSuccess(with message: String) {
        let indicator = SPIndicatorView(title: message, message: "", preset: .done)
        indicator.presentWindow = UIWindow.shutUpKeyWindow
        indicator.present(haptic: .success, completion: nil)
    }

    static func presentAlert(with message: String) {
        onMainThread {
            let alert = UIAlertController(title: "", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Done", style: .default, handler: nil))
            UIWindow.shutUpKeyWindow?.topMostViewController?.present(alert, animated: true, completion: nil)
        }
    }

    static func presentError(with message: String, delay: Double = 0) {
        debugPrint("<InterfaceError> \(message)")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // Banner-style errors need short titles; server-provided text can
            // be any length.
            let title = message.count > 25 ? String(message.prefix(25)) + "…" : message
            let indicator = SPIndicatorView(title: title, message: "", preset: .error)
            indicator.presentWindow = UIWindow.shutUpKeyWindow
            indicator.present(haptic: .error, completion: nil)
        }
    }
}
