//
//  AgentSettings.swift
//  Tamio (macOS)
//
//  Settings › MCP: the server's switch (on by default), how to set an agent
//  up (commands, the skill, a prompt to paste), and what agents did lately.
//

import SwiftUI
import TamioDesign
import TamioModule

struct AgentServerSettings: View {
    @ObservedObject private var bridge = AgentBridge.shared

    var body: some View {
        RXDividedStack {
            SwitchRow(
                "MCP server",
                description: "Agents (Claude Code, Codex, any MCP client) can list your servers and their live status, and, when you approve, run commands and manage servers, keys, snippets and port forwards. They never get passwords or private keys.",
                isOn: $bridge.isEnabled
            )
            RXFormRow("Status") {
                HStack(spacing: 6) {
                    Circle()
                        .fill(bridge.isRunning ? Color.rxSuccess : Color.rxInkTertiary)
                        .frame(width: 7, height: 7)
                    Text(bridge.isRunning ? "Running" : "Off")
                        .font(.rxBody)
                        .foregroundStyle(.rxInkSecondary)
                }
            }
            RXFormRow("Approvals", description: "Every command and change asks you first. “Allow for 1 Hour” lets that agent go on without asking until then.") {
                EmptyView()
            }
        }
    }
}

struct AgentSetupSettings: View {
    @ObservedObject private var bridge = AgentBridge.shared
    @State private var installed: String?

    var body: some View {
        RXDividedStack {
            copyRow("Claude Code", description: "Run once in Terminal.", text: bridge.claudeCommand)
            copyRow("Codex", description: "Add to ~/.codex/config.toml.", text: bridge.codexConfig)
            RXFormRow("Tamio skill", description: installed ?? "Teaches an agent the rules: read a server's activity first, run through Tamio, report what it does by other means.") {
                HStack(spacing: RX.Space.s2) {
                    Button("Copy Command") { UIBridge.sendPasteboard(str: bridge.skillInstallCommand) }
                        .buttonStyle(.rx)
                        .help(bridge.skillInstallCommand)
                    Button("Install Skill") {
                        installed = bridge.installSkill().map { "Not installed: \($0)" } ?? "Installed in ~/.claude/skills/tamio."
                    }
                    .buttonStyle(.rxPrimary)
                }
            }
            copyRow("Prompt", description: "Paste into any agent: where Tamio's MCP server and skill are, and how to use them.", text: bridge.agentPrompt)
        }
    }

    func copyRow(_ title: String, description: String, text: String) -> some View {
        RXFormRow(title, description: description, alignTop: true) {
            VStack(alignment: .trailing, spacing: RX.Space.s2) {
                Text(text)
                    .font(.rxCode)
                    .foregroundStyle(.rxInk)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 380, alignment: .leading)
                    .padding(RX.Space.s2)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.rxSurfaceSunken))
                Button("Copy") { UIBridge.sendPasteboard(str: text) }
                    .buttonStyle(.rx(size: .small))
            }
        }
    }
}

struct AgentActivitySettings: View {
    @ObservedObject private var log = AgentServer.shared.log

    var body: some View {
        RXDividedStack {
            if log.entries.isEmpty {
                RXFormRow("No activity yet", description: "What agents run and change, and what they report, shows here and on each server.") { EmptyView() }
            } else {
                ForEach(log.entries.suffix(30).reversed()) { entry in
                    AgentActivityRow(entry: entry, showsHosts: true)
                        .padding(.vertical, RX.Space.s2)
                }
                HStack {
                    Spacer()
                    Button("Clear Activity…") {
                        UIBridge.requiresConfirmation(
                            message: "Clear all agent activity?",
                            informative: "It is cleared on this Mac only; with iCloud sync, other Macs keep theirs.",
                            confirmTitle: "Clear",
                            destructive: true
                        ) { if $0 { log.clear() } }
                    }
                    .buttonStyle(.rx(size: .small))
                }
                .padding(.vertical, RX.Space.s2)
            }
        }
    }
}

/// One entry: who, what, where, when, and how it went.
struct AgentActivityRow: View {
    let entry: AgentActivity
    var showsHosts = false
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: RX.Space.s2) {
                Image(systemName: entry.tool == "report" ? "text.bubble" : entry.tool.hasPrefix("run_") ? "terminal" : "pencil")
                    .font(.system(size: 11))
                    .foregroundStyle(.rxAccent)
                    .frame(width: 14)
                Text(entry.summary)
                    .font(.rxBodyStrong)
                    .lineLimit(1)
                Spacer(minLength: RX.Space.s2)
                Text(RXFormat.relative(entry.date))
                    .font(.rxHelp)
                    .foregroundStyle(.rxInkSecondary)
                    .fixedSize()
            }
            Text([entry.client, entry.device, showsHosts ? entry.hostNames.joined(separator: ", ") : nil, entry.outcome]
                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.rxHelp)
                .foregroundStyle(entry.outcome.hasPrefix("declined") ? Color.rxWarning : Color.rxInkSecondary)
                .lineLimit(2)
            if !entry.detail.isEmpty {
                Text(entry.detail)
                    .font(.rxCode)
                    .foregroundStyle(.rxInk)
                    .lineLimit(expanded ? nil : 2)
                    .textSelection(.enabled)
                    .onTapGesture { expanded.toggle() }
            }
            if expanded {
                ForEach(entry.results, id: \.host) { result in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(result.host) · \(result.exitCode.map { "exit \($0)" } ?? "no exit code")")
                            .font(.rxHelp)
                            .foregroundStyle(result.exitCode == 0 ? Color.rxInkSecondary : Color.rxDanger)
                        if !result.tail.isEmpty {
                            Text(result.tail.split(separator: "\n").suffix(6).joined(separator: "\n"))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.rxInkSecondary)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { expanded.toggle() }
    }
}
