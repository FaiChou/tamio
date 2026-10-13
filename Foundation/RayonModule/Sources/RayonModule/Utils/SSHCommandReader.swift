//
//  SSHCommandReader.swift
//  Rayon
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
        let tokens = parser.components(separatedBy: " ").filter { !$0.isEmpty }
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
