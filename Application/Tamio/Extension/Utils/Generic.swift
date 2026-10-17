//
//  Generic.swift
//  Tamio
//
//  Created by Lakr Aream on 2022/2/11.
//

import Foundation
import TamioModule
import SwiftUI

enum TamioUtil {
    /// The window scene the user is working in: the main window, never a
    /// menu bar popover's.
    @MainActor static func mainScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { !($0.delegate is TraySceneDelegate) }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }

    /// The view controller a sheet goes on: the topmost one in the main window.
    @MainActor static func topViewController() -> UIViewController? {
        let window = mainScene().flatMap { scene in scene.windows.first { $0.isKeyWindow } ?? scene.windows.first }
        var top = window?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}

/// Presents SwiftUI content as a sheet on the frontmost window from code that
/// has no view to hang a `.sheet` on (router actions, menu bar).
enum SheetPresenter {
    @MainActor
    static func present<Content: View>(
        size: CGSize? = nil,
        @ViewBuilder content: @escaping (_ dismiss: @escaping () -> Void) -> Content
    ) {
        weak var presented: UIViewController?
        let dismiss = {
            presented?.dismiss(animated: true)
            presented = nil
        }
        let root = content(dismiss)
            .environmentObject(TamioStore.shared)
            .frame(width: size?.width, height: size?.height)
        let controller = UIHostingController(rootView: root)
        controller.modalPresentationStyle = .formSheet
        // The sheet is as large as its content, as a SwiftUI sheet is.
        controller.sizingOptions = .preferredContentSize
        presented = controller
        TamioUtil.topViewController()?.present(controller, animated: true)
    }
}

enum ServerPickerPanel {
    /// The multi-select server picker used by Open Terminals, Run snippet and Port Forward.
    @MainActor
    static func present(
        title: String,
        lead: String? = nil,
        confirmTitle: String,
        allowsMany: Bool,
        preselected: Set<RDMachine.ID> = [],
        onComplete: @escaping ([RDMachine.ID]) -> Void
    ) {
        SheetPresenter.present { dismiss in
            ServerPickerSheet(
                title: title,
                lead: lead,
                confirmTitle: confirmTitle,
                allowsMany: allowsMany,
                initialSelection: preselected
            ) { selection in
                dismiss()
                guard let selection, !selection.isEmpty else { return }
                onComplete(selection)
            }
        }
    }
}

enum IdentityPickerPanel {
    @MainActor
    static func present(onComplete: @escaping (RDIdentity.ID?) -> Void) {
        SheetPresenter.present { dismiss in
            IdentityPickerSheet { selection in
                dismiss()
                onComplete(selection)
            }
        }
    }
}
