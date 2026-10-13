//
//  Util.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/3.
//

import Foundation
import LocalAuthentication
import RayonModule
import SwiftUI
import UIKit

let preferredPopOverSize = CGSize(width: 700, height: 555)

enum RayonUtil {
    private static func deviceHasPassword() -> Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    typealias DeviceOwnershipCheckSuccess = Bool
    static func deviceOwnershipAuthenticate(onComplete: @escaping (DeviceOwnershipCheckSuccess) -> Void) {
        DispatchQueue.global().async {
            guard deviceHasPassword() else {
                onMainThread {
                    onComplete(true)
                }
                return
            }
            let context = LAContext()
            let reason = "Performing privacy sensitive operation requires device ownership authenticated"
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            ) { success, error in
                onMainThread {
                    if success {
                        debugPrint(#function, "success")
                        onComplete(true)
                    } else {
                        debugPrint(#function, "failure", error?.localizedDescription ?? "Unknown Error")
                        onComplete(false)
                    }
                }
            }
        }
    }

    /// Presents a SwiftUI view in a form-sheet hosting controller over the
    /// topmost view controller. Shared by all modal picker flows.
    /// - Returns: false when there is no window to present from.
    @discardableResult
    static func presentModalSheet<Content: View>(rootView: Content) -> Bool {
        let controller = UIHostingController(rootView: rootView)
        controller.isModalInPresentation = true
        controller.modalTransitionStyle = .coverVertical
        controller.modalPresentationStyle = .formSheet
        controller.preferredContentSize = preferredPopOverSize
        guard let presenter = UIWindow.shutUpKeyWindow?.topMostViewController else {
            return false
        }
        presenter.present(controller, animated: true, completion: nil)
        return true
    }

    static func selectIdentity() async -> RDIdentity.ID? {
        debugPrint("Picking Identity")
        return await withCheckedContinuation { continuation in
            onMainThread {
                let picker = NavigationStack {
                    PickIdentityView {
                        continuation.resume(returning: $0)
                    }
                }
                .expended()
                if !presentModalSheet(rootView: picker) {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    static func selectMachine(canSelectMany: Bool = true) async -> [RDMachine.ID] {
        debugPrint("Picking Machine")
        return await withCheckedContinuation { continuation in
            onMainThread {
                let picker = NavigationStack {
                    PickMachineView(completion: {
                        continuation.resume(returning: $0)
                    }, canSelectMany: canSelectMany)
                }
                .expended()
                if !presentModalSheet(rootView: picker) {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    static func selectOneMachine() async -> [RDMachine.ID] {
        await selectMachine(canSelectMany: false)
    }

    static func createExecuteFor(snippet: RDSnippet) {
        Task {
            let machineIds = await selectMachine()
            debugPrint(machineIds)
            guard !machineIds.isEmpty else {
                return
            }
            // so that picker is closed
            onMainThread(delay: 0.6) {
                let runner = NavigationStack {
                    let context = SnippetExecuteContext(snippet: snippet, machineGroup: machineIds.map { machineId in
                        RayonStore.shared.machineGroup[machineId]
                    })
                    SnippetExecuteView(context: context)
                }
                .expended()
                .navigationBarTitleDisplayMode(.inline)
                presentModalSheet(rootView: runner)
            }
        }
    }
}
