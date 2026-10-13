//
//  PortForwardBackend.swift
//  Rayon (macOS)
//
//  Created by Lakr Aream on 2022/3/11.
//

import Combine
import NSRemoteShell
import RayonModule

class PortForwardBackend: ObservableObject {
    // Keep the existing caller-managed queue and lock ownership.
    nonisolated(unsafe) static let shared = PortForwardBackend()

    private init() {}

    @Published var container = [Context]()
    struct Context: Identifiable {
        var id = UUID()
        let info: RDPortForward
        let machine: RDMachine
        let shell: NSRemoteShell
    }

    @Published var lastHint: [Context.ID: String] = [:]

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
        let context = Context(
            info: portFwd,
            machine: machine,
            shell: .init()
        )
        container.append(context)
        beginLifecycle(for: context)
    }

    func putHint(for pid: RDPortForward.ID, with: String) {
        onMainThread {
            self.lastHint[pid] = with
        }
    }

    func beginLifecycle(for context: Context) {
        DispatchQueue.global().async {
            self.runLifecycle(for: context)
            // However the lifecycle ended — connect or auth failure, or the
            // channel closing — the session is over: release the shell and
            // drop the context so the switch goes back off (endSession can
            // no longer reach it once it leaves the container).
            context.shell.requestDisconnectAndWait()
            context.shell.destroyPermanently()
            self.endLifecycle(for: context)
        }
    }

    private func runLifecycle(for context: Context) {
        putHint(for: context.info.id, with: "awaiting connect")
        context.shell
            .applyConnection(for: context.machine, timeout: RayonStore.shared.timeoutNumber)
            .requestConnectAndWait()
        guard context.shell.isConnected else {
            putHint(for: context.info.id, with: "failed connect")
            return
        }
        guard let str = context.machine.associatedIdentity,
              let aid = UUID(uuidString: str)
        else {
            putHint(for: context.info.id, with: "failed authenticate")
            return
        }
        let identity = RayonStore.shared.identityGroup[aid]
        guard !identity.username.isEmpty else {
            putHint(for: context.info.id, with: "failed authenticate")
            return
        }
        identity.callAuthenticationWith(remote: context.shell)
        guard context.shell.isAuthenticated else {
            putHint(for: context.info.id, with: "failed authenticate")
            return
        }
        putHint(for: context.info.id, with: "opening channel")
        switch context.info.forwardOrientation {
        case .listenRemote:
            context.shell.createPortForward(
                withRemotePort: NSNumber(value: context.info.bindPort),
                withForwardTargetHost: context.info.targetHost,
                withForwardTargetPort: NSNumber(value: context.info.targetPort)
            ) {
                PortForwardBackend.shared.putHint(for: context.info.id, with: "forward running")
            } withContinuationHandler: {
                true // we are using shell.disconnect for shutdown
            }
        case .listenLocal:
            context.shell.createPortForward(
                withLocalPort: NSNumber(value: context.info.bindPort),
                withForwardTargetHost: context.info.targetHost,
                withForwardTargetPort: NSNumber(value: context.info.targetPort)
            ) {
                PortForwardBackend.shared.putHint(for: context.info.id, with: "forward running")
            } withContinuationHandler: {
                true // we are using shell.disconnect for shutdown
            }
        }
        putHint(for: context.info.id, with: "forward stopped")
    }

    /// Removes a finished session's context, so the row's switch turns off.
    private func endLifecycle(for context: Context) {
        onMainThread {
            self.container.removeAll { $0.id == context.id }
        }
    }

    func sessionExists(withPortForwardID pid: RDPortForward.ID) -> Bool {
        container.first { $0.info.id == pid } != nil
    }

    func endSession(withPortForwardID pid: RDPortForward.ID) {
        let index = container.firstIndex { $0.info.id == pid }
        putHint(for: pid, with: "terminating")
        if let index = index {
            let context = container.remove(at: index)
            DispatchQueue.global().async {
                context.shell.requestDisconnectAndWait()
                context.shell.destroyPermanently()
            }
        }
    }
}
