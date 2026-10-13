//
//  SnippetExecuteContext.swift
//  mCatussh
//
//  The per-server run lives in CatusshModule.SnippetExecSession; this
//  context keeps the batch: terminals, progress and per-server close.
//

import NSRemoteShell
import CatusshModule
import SwiftUI
import CatusshTerminal

class SnippetExecuteContext: ObservableObject {
    let snippet: RDSnippet
    let machineGroup: [RDMachine]
    var shellGroup: [NSRemoteShell]
    let terminalGroup: [CatusshTerminalView]

    @Published var interfaceAllocated = false

    @Published var running: [RDMachine] = []
    @Published var completed: [RDMachine] = []
    @Published var hasError: Bool = false
    @Published var completedProgress: Float = 0
    @Published var totalProgress: Float = 0

    static let queue = DispatchQueue(label: "me.mizorewww.snippet.exec", attributes: .concurrent)

    init(snippet: RDSnippet, machineGroup: [RDMachine]) {
        self.snippet = snippet
        self.machineGroup = machineGroup
        var buildTermUI = [CatusshTerminalView]()
        machineGroup.forEach { _ in
            buildTermUI.append(.init())
        }
        terminalGroup = buildTermUI
        totalProgress = Float(machineGroup.count)
        shellGroup = machineGroup
            .map { NSRemoteShell.configured(for: $0, timeout: CatusshStore.shared.timeoutNumber) }
    }

    deinit {
        debugPrint("\(self) \(#function)")
    }

    func beginBootstrap() {
        interfaceAllocated = true
        running = machineGroup
        updateProgress()
        for idx in 0 ..< machineGroup.count {
            let machine = machineGroup[idx]
            let shell = shellGroup[idx]
            let term = terminalGroup[idx]
            SnippetExecuteContext.queue.async {
                self.createExecute(for: machine, shell: shell, term: term)
            }
        }
    }

    func updateProgress() {
        onMainThread { [self] in
            debugPrint("\(self) \(completed.count)")
            completedProgress = Float(completed.count)
            totalProgress = Float(machineGroup.count)
        }
    }

    func reportError() {
        onMainThread { self.hasError = true }
    }

    func createExecute(for machine: RDMachine, shell: NSRemoteShell, term: CatusshTerminalView) {
        defer {
            moveToComplete(for: machine.id)
        }
        // Runs on the exec queue; the store read is its worker snapshot.
        term.setTerminalFontSize(with: CatusshStore.shared.workerTerminalFontSize)
        term.write("[*] connecting to host...\r\n")
        let outcome = SnippetExecSession(machine: machine, shell: shell).execute(
            snippet.code,
            onBegin: {
                term.write("[*] Execute Begin\r\n")
            },
            onOutput: { output in
                term.write(output)
            },
            withContinuationHandler: {
                true // close it to cancel the exec
            }
        )
        switch outcome {
        case .completed:
            term.write("\r\n\r\n[*] Execution Completed ")
        case .connectFailed:
            term.write("[E] failed to connect\r\n")
            reportError()
        case .authenticateFailed:
            term.write("[E] failed to authenticate session\r\n")
            reportError()
        }
    }

    func moveToComplete(for mid: RDMachine.ID) {
        onMainThread { [self] in
            defer { updateProgress() }
            // shellGroup is parallel to machineGroup; running shrinks as
            // sessions complete, so its index must not be used here.
            if let index = running.firstIndex(where: { $0.id == mid }) {
                let get = running.remove(at: index)
                completed.append(get)
            }
            if let shellIndex = machineGroup.firstIndex(where: { $0.id == mid }) {
                shellGroup[shellIndex] = .init()
            }
        }
    }

    func close(for mid: RDMachine.ID) {
        onMainThread { [self] in
            defer { updateProgress() }
            let index = machineGroup.firstIndex { $0.id == mid }
            if let index = index {
                let shell = shellGroup[index]
                SnippetExecuteContext.queue.async {
                    shell.requestDisconnectAndWait()
                }
            }
        }
    }
}
