//
//  InterfaceBridge.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/9.
//

import Foundation
import RayonModule
import UIKit

// onMainThread(delay:run:) is provided by RayonModule.

/// Not actually a Actor but I like it
/// - Parameter run: the job to be fired on main thread
func mainActorUI(delay: Double = 0, run: @escaping @MainActor () -> Void) {
    guard delay == 0, Thread.isMainThread else {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            run()
        }
        return
    }
    // The guard above establishes the existing main-thread fast path.
    MainActor.assumeIsolated { run() }
}

enum UIBridge {
    static let itemSpacing: Double = 10

    static func sendPasteboard(str: String) {
        debugPrint("\(#function) \(str)")
        UIPasteboard.general.string = str
    }

    @MainActor static func open(url: URL) {
        UIApplication.shared.open(url)
    }

    @MainActor static func askForInput(title: String, message: String, defaultValue: String, complete: @escaping (String) -> Void) {
        Mac.bridge?.alert(
            message: title,
            informative: message,
            buttons: ["OK", "Cancel"],
            destructiveFirstButton: false,
            textField: defaultValue
        ) { button, text in
            if button == 0, let text { complete(text) }
        }
    }
}
