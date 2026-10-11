//
//  DoubleConfirm.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import RayonModule
import SwiftUI

extension UIBridge {
    /// ConfirmDialog: the title names the thing, one sentence of consequence,
    /// a verb on the confirming button and Cancel. Skipped when
    /// Settings › General › Ask before closing is off.
    static func requiresConfirmation(
        message: String,
        informative: String? = nil,
        confirmTitle: String = "Continue",
        destructive: Bool = false,
        confirmation: @escaping (Bool) -> Void
    ) {
        // Keep the immediate callback when confirmation is disabled.
        nonisolated(unsafe) let confirmation = confirmation
        if RayonStore.shared.disableConformation {
            confirmation(true)
            return
        }
        guard let bridge = Mac.bridge else {
            confirmation(false)
            return
        }
        bridge.alert(
            message: message,
            informative: informative,
            buttons: [confirmTitle, "Cancel"],
            destructiveFirstButton: destructive,
            textField: nil
        ) { button, _ in
            confirmation(button == 0)
        }
    }
}

/// Bridges RayonModule's shared file-transfer core to the Mac app's UI.
final class MacFileTransferUIHandler: FileTransferUIHandler {
    func presentError(_ message: String) {
        UIBridge.presentError(with: message)
    }

    func requiresConfirmation(_ message: String, completion: @escaping (Bool) -> Void) {
        UIBridge.requiresConfirmation(message: message, confirmation: completion)
    }

    func autoOpenInterface(_ context: FileTransferContext) {
        // Opened for the editor, the session stays on the editor.
        if AppRouter.shared.route == .editor(context.id) { return }
        AppRouter.shared.route = .transfer(context.id)
    }
}
