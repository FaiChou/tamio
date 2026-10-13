//
//  PortForwardBackend.swift
//  mRayon
//
//  The session lifecycle lives in RayonModule.PortForwardContext; this
//  backend keeps the container, the per-forward hints and validation.
//

import Combine
import Foundation
import RayonModule

class PortForwardBackend: ObservableObject {
    static let shared = PortForwardBackend()

    private init() {}

    @Published var container = [PortForwardContext]()

    @Published var lastHint = [RDPortForward.ID: String]()

    func createSession(withPortForwardID pid: RDPortForward.ID) {
        if sessionExists(withPortForwardID: pid) {
            // multiple start
            return
        }
        let portFwd = RayonStore.shared.portForwardGroup[pid]
        guard portFwd.isValid(),
              let mid = portFwd.usingMachine
        else {
            UIBridge.presentError(with: "Invalid Info")
            return
        }
        let machine = RayonStore.shared.machineGroup[mid]
        guard machine.isNotPlaceholder() else {
            UIBridge.presentError(with: "Invalid Info")
            return
        }
        let context = PortForwardContext(
            info: portFwd,
            machine: machine
        )
        context.hintHandler = { [weak self] hint in
            self?.putHint(for: pid, with: hint)
        }
        context.terminationHandler = { [weak self] context in
            self?.endLifecycle(for: context)
        }
        container.append(context)
        context.begin()
        UIBridge.presentSuccess(with: "Forward Created")
    }

    private func putHint(for pid: RDPortForward.ID, with hint: String) {
        onMainThread {
            self.lastHint[pid] = hint
        }
    }

    /// Removes a finished session's context, so the row's switch turns off.
    /// Called on the main thread by the context's termination handler.
    private func endLifecycle(for context: PortForwardContext) {
        container.removeAll { $0.id == context.id }
    }

    func sessionExists(withPortForwardID pid: RDPortForward.ID) -> Bool {
        container.first { $0.info.id == pid } != nil
    }

    func endSession(withPortForwardID pid: RDPortForward.ID) {
        let index = container.firstIndex { $0.info.id == pid }
        if let index = index {
            let context = container.remove(at: index)
            context.terminate()
        }
    }
}
