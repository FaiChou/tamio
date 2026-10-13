//
//  PortForwardContext.swift
//  RayonModule
//
//  Shared port-forward session, previously duplicated between the macOS
//  and iOS apps. A reconnect is driven by the forward channel dropping
//  (its round ends), not by polling; termination is lock-protected.
//

import Foundation
import NSRemoteShell

public class PortForwardContext: ObservableObject, Identifiable {
    public var id = UUID()
    public let info: RDPortForward
    public let machine: RDMachine
    public let shell: NSRemoteShell

    /// Hint sink for the owning backend, called from the lifecycle thread.
    public var hintHandler: ((String) -> Void)?

    /// Called once on the main thread after the lifecycle exits, so the
    /// backend can drop the context and the switch goes back off.
    public var terminationHandler: ((PortForwardContext) -> Void)?

    /// Backoff before reconnecting after a round ends on its own.
    public var reconnectDelay: TimeInterval = 3

    // The lifecycle thread reads closed each round while terminate writes
    // it from the UI thread; the lock keeps that pair safe.
    private let stateAccessLock = NSLock()
    private var _closed = false
    public private(set) var closed: Bool {
        get {
            stateAccessLock.lock()
            defer { stateAccessLock.unlock() }
            return _closed
        }
        set {
            stateAccessLock.lock()
            defer { stateAccessLock.unlock() }
            _closed = newValue
        }
    }

    private let reconnectSignal = DispatchSemaphore(value: 0)

    public init(info: RDPortForward, machine: RDMachine, shell: NSRemoteShell = .init()) {
        self.info = info
        self.machine = machine
        self.shell = shell
    }

    func putHint(_ hint: String) {
        hintHandler?(hint)
    }

    /// Starts the lifecycle on a background queue and returns immediately.
    public func begin() {
        DispatchQueue.global().async {
            self.runLifecycle()
        }
    }

    /// Asks the session to stop: a running round is cut off by the
    /// disconnect and a pending reconnect returns at once.
    public func terminate() {
        closed = true
        reconnectSignal.signal()
        let shell = shell
        DispatchQueue.global().async { [weak shell] in
            shell?.requestDisconnectAndWait()
        }
    }

    private func runLifecycle() {
        defer {
            shell.requestDisconnectAndWait()
            shell.destroyPermanently()
            putHint("terminated")
            let handler = terminationHandler
            onMainThread { handler?(self) }
        }
        while !closed {
            runRound()
            guard !closed else { break }
            // Back off before reconnecting; terminate() signals the wait out.
            _ = reconnectSignal.wait(timeout: .now() + reconnectDelay)
        }
    }

    private func runRound() {
        putHint("awaiting connect")
        shell
            .applyConnection(for: machine, timeout: RayonStore.shared.timeoutNumber)
            .requestConnectAndWait()
        guard shell.isConnected else {
            putHint("failed connect")
            return
        }
        guard let identity = RayonStore.shared.associatedIdentity(for: machine) else {
            putHint("failed authenticate")
            return
        }
        identity.callAuthenticationWith(remote: shell)
        guard shell.isAuthenticated else {
            putHint("failed authenticate")
            return
        }
        putHint("opening channel")
        switch info.forwardOrientation {
        case .listenRemote:
            shell.createPortForward(
                withRemotePort: NSNumber(value: info.bindPort),
                withForwardTargetHost: info.targetHost,
                withForwardTargetPort: NSNumber(value: info.targetPort)
            ) {
                self.putHint("forward running")
            } withContinuationHandler: {
                true // we are using shell.disconnect for shutdown
            }
        case .listenLocal:
            shell.createPortForward(
                withLocalPort: NSNumber(value: info.bindPort),
                withForwardTargetHost: info.targetHost,
                withForwardTargetPort: NSNumber(value: info.targetPort)
            ) {
                self.putHint("forward running")
            } withContinuationHandler: {
                true // we are using shell.disconnect for shutdown
            }
        }
        putHint("forward stopped")
    }
}
