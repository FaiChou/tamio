//
//  ServerInfo.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/12.
//

import Combine
import Foundation
import NSRemoteShell

/// Mirror of RayonModule's `onMainThread`; MachineStatus sits below
/// RayonModule in the package graph and cannot import it.
/// - Parameter run: the job to be fired on the main thread
func onMainThread(delay: Double = 0, run: @escaping () -> Void) {
    // Preserve the legacy model callbacks without claiming the models are Sendable.
    nonisolated(unsafe) let run = run
    guard delay == 0, Thread.isMainThread else {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            run()
        }
        return
    }
    run()
}

public class ServerStatus: ObservableObject, Equatable {
    public init() {}

    static let outputSeparator = "[*******]"

    enum ScriptCollection: String, CaseIterable {
        case obtainProcessInfo =
            """
             /bin/cat /proc/stat && /bin/sleep 1 && echo '[*******]' && /bin/cat /proc/stat
            """
        case obtainMemoryInfo =
            """
             /bin/cat /proc/meminfo
            """
        case obtainFileSystemInfo =
            """
             /bin/df -Pk
            """
        case obtainHostname =
            """
             ([ -f /proc/sys/kernel/hostname ] && cat /proc/sys/kernel/hostname )|| echo "localhost"
            """
        case obtainUptime =
            """
             /bin/cat /proc/uptime
            """
        case obtainLoadavg =
            """
             /bin/cat /proc/loadavg
            """
        case obtainRelease =
            """
             /bin/cat /etc/os-release
            """
        case obtainNetworkInfo =
            """
             /bin/cat /proc/net/dev && /bin/sleep 1 && echo '[*******]' && /bin/cat /proc/net/dev
            """
        case obtainGraphicsInfo =
            """
             nvidia-smi -q -x | tr -d "[\t\n]" || echo "no nvidia gpu available"
            """
    }

    static func downloadResultFrom(shell: NSRemoteShell, command: ScriptCollection, timeout: Double) -> String {
        guard shell.isConnected, shell.isAuthenticated else {
            return ""
        }
        var result = ""
        shell.beginExecute(
            withCommand: command.rawValue,
            withTimeout: NSNumber(value: timeout),
            withOnCreate: {},
            withOutput: { result.append($0) },
            withContinuationHandler: nil
        )
        return result
    }

    @Published public var processor: ProcessorInfo = .init()
    @Published public var fileSystem: FileSystemInfo = .init()
    @Published public var memory: MemoryInfo = .init()
    @Published public var system: SystemInfo = .init()
    @Published public var network: NetworkInfo = .init()

    // not all server have gpu, bro
    @Published public var graphics: GraphicsInfo? = nil

    public static func == (lhs: ServerStatus, rhs: ServerStatus) -> Bool {
        lhs.processor == rhs.processor &&
            lhs.fileSystem == rhs.fileSystem &&
            lhs.memory == rhs.memory &&
            lhs.system == rhs.system &&
            lhs.network == rhs.network &&
            lhs.graphics == rhs.graphics
    }

    private static let queue = DispatchQueue(label: "me.mizorewww.rayon.info", attributes: .concurrent)

    /// Refreshes every info group, bounding each remote command by
    /// `timeout` seconds so a hung probe (a driverless `nvidia-smi`, say)
    /// cannot freeze the monitor loop forever.
    public func requestInfoAndWait(with remote: NSRemoteShell, timeout: Double) {
        let group = DispatchGroup()
        let queue = Self.queue
        group.enter()
        queue.async { [weak self] in
            defer { group.leave() }
            let info = ProcessorInfo(withRemote: remote, timeout: timeout) ?? .init()
            onMainThread { [weak self] in
                self?.processor = info
            }
        }
        group.enter()
        queue.async { [weak self] in
            defer { group.leave() }
            let info = FileSystemInfo(withRemote: remote, timeout: timeout) ?? .init()
            onMainThread { [weak self] in
                self?.fileSystem = info
            }
        }
        group.enter()
        queue.async { [weak self] in
            defer { group.leave() }
            let info = MemoryInfo(withRemote: remote, timeout: timeout) ?? .init()
            onMainThread { [weak self] in
                self?.memory = info
            }
        }
        group.enter()
        queue.async { [weak self] in
            defer { group.leave() }
            let info = SystemInfo(withRemote: remote, timeout: timeout) ?? .init()
            onMainThread { [weak self] in
                self?.system = info
            }
        }
        group.enter()
        queue.async { [weak self] in
            defer { group.leave() }
            let info = NetworkInfo(withRemote: remote, timeout: timeout) ?? .init()
            onMainThread { [weak self] in
                self?.network = info
            }
        }
        group.enter()
        queue.async { [weak self] in
            defer { group.leave() }
            let info = GraphicsInfo(withRemote: remote, timeout: timeout)
            onMainThread { [weak self] in
                self?.graphics = info
            }
        }
        group.wait()
    }
}
