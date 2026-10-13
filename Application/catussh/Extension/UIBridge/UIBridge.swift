//
//  InterfaceBridge.swift
//  catussh
//
//  Created by Lakr Aream on 2022/2/9.
//

import Foundation
import CatusshModule
import UIKit

enum UIBridge {
    static func sendPasteboard(str: String) {
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
