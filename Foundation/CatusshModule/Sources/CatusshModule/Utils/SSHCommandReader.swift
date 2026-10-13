//
//  SSHCommandReader.swift
//  catussh
//
//  Created by Lakr Aream on 2022/2/9.
//

import Foundation

public struct SSHCommandReader: Codable, Equatable {
    public let remoteAddress: String
    public let remotePort: String
    public let username: String

    public var command: String {
        "ssh \(username)@\(remoteAddress) -p \(remotePort)"
    }

    public init?(command: String) {
        var parser = command.trimmingCharacters(in: .whitespacesAndNewlines)
        // Only the "ssh " prefix is case-insensitive; the username and host
        // keep their case, a Linux username is case-sensitive.
        guard parser.lowercased().hasPrefix("ssh ") else {
            return nil
        }
        // Collapse repeated spaces so pasting "ssh  user@host" still parses.
        while parser.contains("  ") {
            parser = parser.replacingOccurrences(of: "  ", with: " ")
        }
        parser.removeFirst(4) // "ssh "
        var tokens = parser.components(separatedBy: " ").filter { !$0.isEmpty }
        // A bare `user@host:port` target is read as an explicit port, the
        // ssh-command syntax Quick Connect accepts next to `-p port`. Only
        // a lone target gets this reading: with flags around, a colon stays
        // part of the host, and several colons can still be an IPv6 host.
        if tokens.count == 1, let token = tokens.first, token.contains("@"),
           token.filter({ $0 == ":" }).count == 1, let colon = token.lastIndex(of: ":")
        {
            tokens = [String(token[..<colon]), "-p", String(token[token.index(after: colon)...])]
        }
        // "-p <port>" may come before or after user@host.
        var target: String?
        var port: String?
        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            if token == "-p", port == nil {
                guard index + 1 < tokens.count, let value = UInt16(tokens[index + 1]) else {
                    return nil
                }
                port = "\(value)"
                index += 2
            } else if target == nil, token.contains("@") {
                target = token
                index += 1
            } else {
                return nil
            }
        }
        guard let reader = target else {
            return nil // requires username, block anonymous login
        }
        let component = reader.components(separatedBy: "@")
        guard component.count == 2 else {
            return nil
        }
        let name = component[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let addr = component[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count > 0, addr.count > 0 else {
            return nil
        }
        username = name
        remoteAddress = addr
        remotePort = port ?? "22"
    }
}

public extension SSHCommandReader {
    /// Parses what was typed into Quick Connect: `user@host`,
    /// `user@host:port` or a full ssh command, with or without the
    /// "ssh " prefix (the prefix match stays case-insensitive).
    init?(quickConnect input: String) {
        var trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if !trimmed.lowercased().hasPrefix("ssh ") { trimmed = "ssh " + trimmed }
        self.init(command: trimmed)
    }

    /// The first candidate worth offering as a completion of what was
    /// typed into Quick Connect: it shares the typed prefix, is not the
    /// typed string itself, and the input is long enough to mean something.
    static func suggestion(for input: String, in candidates: some Sequence<String>) -> String? {
        guard input.count > 2 else { return nil }
        let typed = input.hasPrefix("ssh ") ? input : "ssh " + input
        return candidates.lazy.first { !$0.isEmpty && $0.hasPrefix(typed) && $0 != typed }
    }
}
