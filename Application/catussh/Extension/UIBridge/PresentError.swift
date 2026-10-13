//
//  PresentError.swift
//  catussh
//
//  Created by Lakr Aream on 2022/2/9.
//

import Foundation
import CatusshModule

extension UIBridge {
    static func presentAlert(with message: String) {
        onMainThread { show(message) }
    }

    static func presentError(with message: String, delay: Double = 0) {
        debugPrint("<InterfaceError> \(message)")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { show(message) }
    }

    /// HIG: use caution symbols sparingly; routine errors don't warrant one.
    private static func show(_ message: String) {
        Mac.bridge?.alert(
            message: message,
            informative: nil,
            buttons: [],
            destructiveFirstButton: false,
            textField: nil,
            completion: nil
        )
    }
}
