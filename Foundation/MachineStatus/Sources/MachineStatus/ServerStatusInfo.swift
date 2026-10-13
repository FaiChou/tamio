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

/// Hands a value out of a @Sendable dispatch block without capturing a
/// var, which Swift 6 diagnoses.
private final class ConcurrentValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func store(_ newValue: Value) {
        lock.lock()
        value = newValue
        lock.unlock()
    }

    func load() -> Value {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

public class ServerStatus: ObservableObject, Equatable {
    public init() {}

    /// The merged monitor script echoes this marker on its own line ahead
    /// of each section; `ProcParsers.splitMonitorSections` only opens a
    /// section on a full-line match, which kernel /proc payloads, df rows
    /// and os-release assignments can never produce. That is what the old
    /// "[*******]" token could not promise inside two samples of one file.
    static let sectionMarkerPrefix = "<<<RAYON-SECTION:"
    static let sectionMarkerSuffix = ">>>"

    /// `nvidia-smi` stays a command of its own: it is slow and missing on
    /// most machines, and its failure must not cost the other sections.
    static let graphicsScript = "nvidia-smi -q -x | tr -d \"[\\t\\n]\" || echo \"no nvidia gpu available\""

    /// One remote run that samples the CPU and network counters twice one
    /// second apart and reads every other /proc payload behind markers, so
    /// a refresh costs one exec channel instead of nine and one remote
    /// second instead of two.
    static func monitorScript() -> String {
        let sections = [
            ("cpu-a", "/bin/cat /proc/stat"),
            ("net-a", "/bin/cat /proc/net/dev"),
            ("wait", "/bin/sleep 1"),
            ("cpu-b", "/bin/cat /proc/stat"),
            ("net-b", "/bin/cat /proc/net/dev"),
            ("mem", "/bin/cat /proc/meminfo"),
            ("df", "/bin/df -Pk"),
            ("uptime", "/bin/cat /proc/uptime"),
            ("loadavg", "/bin/cat /proc/loadavg"),
            ("hostname", "([ -f /proc/sys/kernel/hostname ] && cat /proc/sys/kernel/hostname )|| echo \"localhost\""),
            ("os-release", "/bin/cat /etc/os-release"),
        ]
        return sections
            .map { name, command in
                "echo '\(sectionMarkerPrefix)\(name)\(sectionMarkerSuffix)'\n\(command)"
            }
            .joined(separator: "\n")
    }

    static func downloadResultFrom(shell: NSRemoteShell, command: String, timeout: Double) -> String {
        guard shell.isConnected, shell.isAuthenticated else {
            return ""
        }
        var result = ""
        shell.beginExecute(
            withCommand: command,
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

    /// Runs the merged monitor script and the GPU probe on two channels,
    /// then parses every section on its own: one section going missing
    /// (a hung `nvidia-smi`, a server without /proc) empties only its
    /// model. `timeout` bounds each channel so a hung probe cannot freeze
    /// the monitor loop forever.
    public func requestInfoAndWait(with remote: NSRemoteShell, timeout: Double) {
        // The shell multiplexes channels internally; claiming it Sendable
        // is for the compiler, like the legacy model callbacks.
        nonisolated(unsafe) let remote = remote
        let group = DispatchGroup()
        let queue = Self.queue

        let mergedOutput = ConcurrentValue("")
        group.enter()
        queue.async {
            defer { group.leave() }
            mergedOutput.store(Self.downloadResultFrom(shell: remote, command: Self.monitorScript(), timeout: timeout))
        }

        let graphicsResult = ConcurrentValue<GraphicsInfo?>(nil)
        group.enter()
        queue.async {
            defer { group.leave() }
            graphicsResult.store(GraphicsInfo(withRemote: remote, timeout: timeout))
        }

        group.wait()

        let sections = ProcParsers.splitMonitorSections(mergedOutput.load())
        let processor = ProcessorInfo(statBefore: sections["cpu-a"], statAfter: sections["cpu-b"]) ?? .init()
        let network = NetworkInfo(netDevBefore: sections["net-a"], netDevAfter: sections["net-b"]) ?? .init()
        let memory = MemoryInfo(meminfo: sections["mem"] ?? "")
        let fileSystem = FileSystemInfo(dfPk: sections["df"] ?? "")
        let load = ProcParsers.parseLoadavg(sections["loadavg"] ?? "")
        let system = SystemInfo(
            release: ProcParsers.parseOsReleaseName(sections["os-release"] ?? ""),
            uptimeInSec: ProcParsers.parseUptime(sections["uptime"] ?? ""),
            hostname: (sections["hostname"] ?? "").replacingOccurrences(of: "\n", with: ""),
            runningProcs: load.runningProcess,
            totalProcs: load.totalProcess,
            load1: load.load1avg,
            load5: load.load5avg,
            load15: load.load15avg
        )
        let graphics = graphicsResult.load()

        onMainThread { [weak self] in
            guard let self else { return }
            self.processor = processor
            self.fileSystem = fileSystem
            self.memory = memory
            self.system = system
            self.network = network
            self.graphics = graphics
        }
    }
}
