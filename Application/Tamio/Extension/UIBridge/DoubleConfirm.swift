//
//  DoubleConfirm.swift
//  Tamio
//
//  Created by Lakr Aream on 2022/2/9.
//

import TamioModule
import SwiftUI

extension UIBridge {
    /// ConfirmDialog: the title names the thing, one sentence of consequence,
    /// a verb on the confirming button and Cancel. Skipped when
    /// Settings › General › Ask before closing is off, unless `always`: losing
    /// unsaved text is asked about whatever the setting.
    static func requiresConfirmation(
        message: String,
        informative: String? = nil,
        confirmTitle: String = "Continue",
        destructive: Bool = false,
        always: Bool = false,
        confirmation: @escaping (Bool) -> Void
    ) {
        // With confirmation disabled the callback fires synchronously;
        // otherwise it comes from the AppKit alert on the main thread.
        // Either way it never crosses to a worker queue.
        nonisolated(unsafe) let confirmation = confirmation
        if TamioStore.shared.disableConformation, !always {
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

/// Bridges TamioModule's shared file-transfer core to the Mac app's UI.
final class MacFileTransferUIHandler: FileTransferUIHandler {
    func presentError(_ message: String) {
        UIBridge.presentError(with: message)
    }

    func requiresConfirmation(_ message: String, completion: @escaping (Bool) -> Void) {
        UIBridge.requiresConfirmation(message: message, confirmation: completion)
    }

    func autoOpenInterface(_ context: FileTransferContext) {
        // The contract calls this on the main thread; the class itself is
        // not MainActor because it witnesses a nonisolated protocol.
        let id = context.id
        MainActor.assumeIsolated {
            AppRouter.shared.route = .transfer(id)
        }
    }
}
