//
//  TerminalManager+Context.swift
//  catussh (macOS)
//
//  The session core lives in CatusshModule.TerminalContext; this shell keeps
//  the platform surface (CatusshTerminalView) the core drives.
//

import Foundation
import CatusshModule
import CatusshTerminal

/// Bridges the shared terminal session core to the platform renderer.
final class TerminalSurfaceBridge: TerminalSessionSurface {
    let termInterface = CatusshTerminalView()

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

extension TerminalManager {
    final class Context: CatusshModule.TerminalContext {
        private let surfaceBridge = TerminalSurfaceBridge()
        var termInterface: CatusshTerminalView { surfaceBridge.termInterface }

        init(machine: RDMachine) {
            super.init(machine: machine, surface: surfaceBridge)
        }

        init(command: SSHCommandReader) {
            super.init(command: command, surface: surfaceBridge)
        }
    }
}
