//
//  TerminalContext.swift
//  mRayon
//
//  The session core lives in RayonModule.TerminalContext; this shell keeps
//  the platform surface, the stored font size and the auto-present modal.
//

import RayonModule
import SwiftUI
import UIKit
import RayonTerminal

/// Bridges the shared terminal session core to the platform renderer.
final class TerminalSurfaceBridge: TerminalSessionSurface {
    let termInterface = RayonTerminalView()

    func write(_ string: String) {
        termInterface.write(string)
    }

    func setupBellChain(_ callback: @escaping () -> Void) {
        termInterface.setupBellChain(callback: callback)
    }

    func setupBufferChain(_ callback: @escaping (String) -> Void) {
        termInterface.setupBufferChain(callback: callback)
    }

    func setupTitleChain(_ callback: @escaping (String) -> Void) {
        termInterface.setupTitleChain(callback: callback)
    }

    func setupSizeChain(_ callback: @escaping (CGSize) -> Void) {
        termInterface.setupSizeChain(callback: callback)
    }
}

final class TerminalContext: RayonModule.TerminalContext {
    private let surfaceBridge = TerminalSurfaceBridge()
    var termInterface: RayonTerminalView { surfaceBridge.termInterface }

    init(machine: RDMachine) {
        super.init(machine: machine, surface: surfaceBridge)
        termInterface.setTerminalFontSize(with: RayonStore.shared.terminalFontSize)
    }

    init(command: SSHCommandReader) {
        super.init(command: command, surface: surfaceBridge)
        termInterface.setTerminalFontSize(with: RayonStore.shared.terminalFontSize)
    }
}

extension TerminalContext {
    struct DefaultPresent: View {
        let context: TerminalContext

        var body: some View {
            DefaultModalPresenter {
                TerminalView(context: context)
            }
        }
    }
}

/// Bridges RayonModule's shared terminal core to UIKit UI.
final class IOSTerminalUIHandler: TerminalUIHandler {
    func autoOpenInterface(_ context: RayonModule.TerminalContext) {
        guard let context = context as? TerminalContext else { return }
        let host = UIHostingController(
            rootView: TerminalContext.DefaultPresent(context: context)
        )
        host.modalTransitionStyle = .coverVertical
        // iPhone: the terminal is full screen with the key bar above the keyboard.
        host.modalPresentationStyle = UIDevice.current.userInterfaceIdiom == .phone ? .fullScreen : .formSheet
        host.preferredContentSize = preferredPopOverSize
        // A batch of terminals can bootstrap while the picker sheet is
        // still animating out; the queue holds each present until the way
        // is clear instead of dropping it on the floor.
        PresentationQueue.present(next: host)
    }
}
