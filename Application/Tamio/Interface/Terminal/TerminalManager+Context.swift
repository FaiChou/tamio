//
//  TerminalManager+Context.swift
//  Tamio (macOS)
//
//  The session core lives in TamioModule.TerminalContext; this shell keeps
//  the platform surface (TamioTerminalView) the core drives.
//

import Foundation
import TamioModule
import TamioTerminal

/// Bridges the shared terminal session core to the platform renderer.
final class TerminalSurfaceBridge: TerminalSessionSurface {
    let termInterface = TamioTerminalView()

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
    final class Context: TamioModule.TerminalContext {
        private let surfaceBridge = TerminalSurfaceBridge()
        var termInterface: TamioTerminalView { surfaceBridge.termInterface }

        init(machine: RDMachine) {
            super.init(machine: machine, surface: surfaceBridge)
        }

        init(command: SSHCommandReader) {
            super.init(command: command, surface: surfaceBridge)
        }
    }
}
