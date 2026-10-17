//
//  SSI+TCPInfo.swift
//  MachineStatus
//
//  TCP counters from /proc/net/snmp and each interface's IPv4 address.
//

import Foundation

public extension ServerStatus {
    /// Counters since boot.
    struct TCPInfo: Codable, Equatable, Hashable {
        public var activeOpens = 0
        public var passiveOpens = 0
        public var attemptFails = 0
        public var outSegments = 0
        public var retransmittedSegments = 0

        public init() {}

        /// Retransmitted segments over sent ones, in percent.
        public var retransmitPercent: Double {
            outSegments > 0 ? Double(retransmittedSegments) / Double(outSegments) * 100 : 0
        }

        /// /proc/net/snmp holds a "Tcp:" line of names, then one of values.
        public init(snmp: String) {
            let lines = snmp.split(separator: "\n").filter { $0.hasPrefix("Tcp:") }
            guard lines.count >= 2 else { return }
            let names = ProcParsers.splitWhitespaceRuns(String(lines[0])).dropFirst().map(String.init)
            let values = ProcParsers.splitWhitespaceRuns(String(lines[1])).dropFirst().map { Int($0) ?? 0 }
            let table = Dictionary(zip(names, values), uniquingKeysWith: { first, _ in first })
            activeOpens = table["ActiveOpens"] ?? 0
            passiveOpens = table["PassiveOpens"] ?? 0
            attemptFails = table["AttemptFails"] ?? 0
            outSegments = table["OutSegs"] ?? 0
            retransmittedSegments = table["RetransSegs"] ?? 0
        }
    }

    /// `ip -o -4 addr show`: "2: eth0    inet 10.0.0.16/24 brd … scope global eth0".
    static func parseIPv4Addresses(_ payload: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in payload.split(separator: "\n") {
            let fields = ProcParsers.splitWhitespaceRuns(String(line))
            guard let inet = fields.firstIndex(of: "inet"), inet + 1 < fields.count, fields.count > 1 else { continue }
            let device = String(fields[1]).trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            let address = fields[inet + 1].split(separator: "/").first.map(String.init) ?? ""
            if result[device] == nil, !address.isEmpty { result[device] = address }
        }
        return result
    }
}
