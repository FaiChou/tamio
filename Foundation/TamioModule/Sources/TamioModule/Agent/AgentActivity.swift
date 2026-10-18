//
//  AgentActivity.swift
//  TamioModule
//
//  What agents did, server by server: every change and run through the MCP
//  server, and what agents report doing over their own SSH connections
//  (log_activity). Kept so the next agent, on this Mac or another, can read
//  what the last one did (get_activity). Entries sync with iCloud like the
//  servers they belong to; they never hold a secret.
//
//  An agent names the task a step serves ("Install nginx"), and every step
//  toward it goes in one entry: its apt update, its repository, its install.
//  The entry reads as what was done, with the steps under it.
//

import Foundation

public struct AgentActivity: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var date = Date()
    /// The Mac it happened on.
    public var device: String
    /// The MCP client ("claude-code", "codex"…).
    public var client: String
    /// The tool, or "report" for what an agent says it did itself.
    public var tool: String
    /// The servers it concerns, by id, and their names at the time.
    public var hosts: [String]
    public var hostNames: [String]
    /// One line: "Ran apt-get upgrade", "Added server prod-web-01".
    public var summary: String
    /// The command, what changed, or the agent's account.
    public var detail: String
    /// "ok", "declined", an error, or "exit 0 on 3, exit 1 on 1".
    public var outcome: String
    /// Per server, for runs: exit code and the output's last lines.
    public var results: [Result]
    /// The goal the steps served, when the agent named one; then `summary`
    /// is the task and `steps` hold what was done toward it.
    public var task: String?
    public var steps: [Step]?
    /// When the last step was added; a newer copy of the entry replaces an
    /// older one in sync.
    public var updated: Date?

    public struct Result: Codable, Equatable, Sendable {
        public var host: String
        public var exitCode: Int?
        public var tail: String
    }

    /// One action toward a task, as it would be an entry of its own.
    public struct Step: Codable, Equatable, Sendable {
        public var date: Date
        public var tool: String
        public var summary: String
        public var detail: String
        public var outcome: String
        public var results: [Result]
    }

    public var lastChange: Date { updated ?? date }

    /// The entry as a step of a task.
    var asStep: Step {
        Step(date: date, tool: tool, summary: summary, detail: detail, outcome: outcome, results: results)
    }

    /// One line per step: the command for a run, else what was done.
    public static func line(_ step: Step) -> String {
        step.tool.hasPrefix("run_") && !step.detail.isEmpty
            ? step.detail.split(separator: "\n").map { "$ " + $0 }.joined(separator: "\n")
            : step.summary
    }
}

@MainActor
public final class AgentActivityLog: ObservableObject {
    public static let limit = 5000

    @Published public private(set) var entries: [AgentActivity] = []

    /// Called with each new entry; iCloud sync sends it on.
    public var onRecord: ((AgentActivity) -> Void)?

    private let file: URL?

    public init(file: URL? = AgentActivityLog.defaultFile) {
        self.file = file
        if let file, let data = try? Data(contentsOf: file),
           let read = try? JSONDecoder.activity.decode([AgentActivity].self, from: data)
        {
            entries = read
        }
    }

    public static var defaultFile: URL? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let folder = support.appendingPathComponent(Bundle.main.bundleIdentifier ?? "sb.moe.tamio", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("agent-activity.json")
    }

    public static var deviceName: String {
        #if DEBUG
            // Screenshots and tests name the Mac themselves.
            if let name = ProcessInfo.processInfo.environment["TAMIO_DEVICE_NAME"] { return name }
        #endif
        let name = ProcessInfo.processInfo.hostName
        return name.hasSuffix(".local") ? String(name.dropLast(6)) : name
    }

    /// A task's steps go in one entry while they keep coming: no more than
    /// this apart, from the same agent on the same Mac.
    public static let taskGap: TimeInterval = 3 * 3600
    public static let stepLimit = 100

    public func add(_ entry: AgentActivity, task: String? = nil) {
        let task = task?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !task.isEmpty else {
            insert(entry)
            onRecord?(entry)
            return
        }
        if let index = entries.lastIndex(where: {
            $0.task?.caseInsensitiveCompare(task) == .orderedSame && $0.client == entry.client
                && $0.device == entry.device && entry.date.timeIntervalSince($0.lastChange) < Self.taskGap
        }) {
            var grouped = entries[index]
            grouped.steps = Array(((grouped.steps ?? []) + [entry.asStep]).suffix(Self.stepLimit))
            Self.fill(&grouped, adding: entry)
            entries[index] = grouped
            save()
            onRecord?(grouped)
            return
        }
        var grouped = entry
        grouped.task = task
        grouped.steps = [entry.asStep]
        grouped.hosts = []
        grouped.hostNames = []
        Self.fill(&grouped, adding: entry)
        insert(grouped)
        onRecord?(grouped)
    }

    /// The task's entry after a step: its servers, all its commands, and how
    /// the last step went.
    private static func fill(_ grouped: inout AgentActivity, adding step: AgentActivity) {
        for (id, name) in zip(step.hosts, step.hostNames) where !grouped.hosts.contains(id) {
            grouped.hosts.append(id)
            grouped.hostNames.append(name)
        }
        let steps = grouped.steps ?? []
        grouped.summary = grouped.task ?? step.summary
        grouped.detail = steps.map(AgentActivity.line).joined(separator: "\n")
        let count = steps.count
        grouped.outcome = count == 1 ? step.outcome : "\(count) steps · last: \(step.outcome)"
        grouped.results = step.results
        grouped.updated = step.date
    }

    /// An entry from another device, or a newer copy of one; not sent on
    /// again.
    public func merge(_ entry: AgentActivity) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            guard entry.lastChange > entries[index].lastChange else { return }
            entries[index] = entry
            save()
            return
        }
        insert(entry)
    }

    private func insert(_ entry: AgentActivity) {
        entries.append(entry)
        entries.sort { $0.date < $1.date }
        if entries.count > Self.limit { entries.removeFirst(entries.count - Self.limit) }
        save()
    }

    public func entries(for machine: RDMachine.ID) -> [AgentActivity] {
        entries.filter { $0.hosts.contains(machine.uuidString) }
    }

    /// When this device's log was last cleared: sync brings back nothing
    /// from before then.
    public var clearedAt: Date? {
        UserDefaults.standard.object(forKey: Self.clearedKey) as? Date
    }

    private static let clearedKey = "sb.moe.tamio.agentActivity.clearedAt"

    public func clear() {
        entries = []
        UserDefaults.standard.set(Date(), forKey: Self.clearedKey)
        save()
    }

    private func save() {
        guard let file, let data = try? JSONEncoder.activity.encode(entries) else { return }
        try? data.write(to: file, options: .atomic)
    }
}

extension JSONEncoder {
    static var activity: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var activity: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
