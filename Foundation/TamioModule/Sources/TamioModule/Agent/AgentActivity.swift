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

    public struct Result: Codable, Equatable, Sendable {
        public var host: String
        public var exitCode: Int?
        public var tail: String
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
        let name = ProcessInfo.processInfo.hostName
        return name.hasSuffix(".local") ? String(name.dropLast(6)) : name
    }

    public func add(_ entry: AgentActivity) {
        insert(entry)
        onRecord?(entry)
    }

    /// An entry from another device; not sent on again.
    public func merge(_ entry: AgentActivity) {
        guard !entries.contains(where: { $0.id == entry.id }) else { return }
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

    public func clear() {
        entries = []
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
