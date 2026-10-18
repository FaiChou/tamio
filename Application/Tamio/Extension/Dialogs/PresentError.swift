//
//  PresentError.swift
//  Tamio
//
//  Created by Lakr Aream on 2022/2/9.
//

import Foundation
import TamioModule

extension Dialogs {
    static func presentAlert(with message: String) {
        onMainThread { MainActor.assumeIsolated { show(message) } }
    }

    static func presentError(with message: String, delay: Double = 0) {
        debugPrint("<InterfaceError> \(message)")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { MainActor.assumeIsolated { show(message) } }
    }

    /// HIG: use caution symbols sparingly; routine errors don't warrant one.
    @MainActor private static func show(_ message: String) {
        Mac.alert(message: message, informative: nil, buttons: [])
    }
}
