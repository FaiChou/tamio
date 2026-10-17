//
//  ReleaseNotes.swift
//  Tamio (macOS)
//
//  What's New: CHANGELOG.md, carried in the app, read into its releases and
//  drawn as Markdown. The same sections are the release notes on GitHub and in
//  the update window (Workflow/Scripts/release-notes.sh). The file is kept to
//  what a changelog needs: "## [version] - date" per release, "###" headings,
//  "-" bullets and paragraphs, with inline Markdown (bold, code, links) in them.
//

import SwiftUI
import TamioDesign

struct ChangelogRelease: Identifiable, Equatable {
    enum Block: Equatable {
        case heading(String)
        case bullet(AttributedString)
        case paragraph(AttributedString)
    }

    var id: String { version }
    let version: String
    let date: String?
    let blocks: [Block]
}

enum Changelog {
    /// Every release with notes, newest first; an empty Unreleased is left out.
    static let releases: [ChangelogRelease] = {
        guard let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return [] }
        return parse(text)
    }()

    static func release(_ version: String) -> ChangelogRelease? {
        releases.first { $0.version == version }
    }

    static func parse(_ text: String) -> [ChangelogRelease] {
        var releases: [ChangelogRelease] = []
        var version: String?
        var date: String?
        var lines: [String] = []

        func finish() {
            guard let version else { return }
            let blocks = self.blocks(joined(lines))
            if !blocks.isEmpty { releases.append(ChangelogRelease(version: version, date: date, blocks: blocks)) }
        }

        for line in text.components(separatedBy: .newlines) {
            if line.hasPrefix("## [") {
                finish()
                // "## [0.2.0] - 2026-11-02"
                let title = line.dropFirst(4)
                version = title.split(separator: "]", maxSplits: 1).first.map(String.init)
                let rest = title.split(separator: "]", maxSplits: 1).dropFirst().first ?? ""
                let day = rest.trimmingCharacters(in: CharacterSet(charactersIn: " -–—"))
                date = day.isEmpty ? nil : day
                lines = []
            } else if version != nil {
                lines.append(line)
            }
        }
        finish()
        return releases
    }

    /// Lines wrapped in the file, joined, as the release notes script does.
    static func joined(_ lines: [String]) -> [String] {
        var result: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let startsBlock = trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("#")
            if !trimmed.isEmpty, let last = result.last, !last.trimmingCharacters(in: .whitespaces).isEmpty, !startsBlock {
                result[result.count - 1] = last + " " + trimmed
            } else {
                result.append(line)
            }
        }
        return result
    }

    static func blocks(_ lines: [String]) -> [ChangelogRelease.Block] {
        lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return nil }
            if trimmed.hasPrefix("#") {
                return .heading(trimmed.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces))
            }
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                return .bullet(inline(String(trimmed.dropFirst(2))))
            }
            return .paragraph(inline(trimmed))
        }
    }

    static func inline(_ markdown: String) -> AttributedString {
        (try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(markdown)
    }
}

/// The releases' notes, newest first: all of them, or the one just installed.
struct WhatsNewSheet: View {
    let title: String
    let releases: [ChangelogRelease]
    let close: () -> Void

    var body: some View {
        SheetScaffold(title) {
            ScrollView {
                VStack(alignment: .leading, spacing: RX.Space.s6) {
                    if releases.isEmpty {
                        Text("No release notes in this copy of Tamio.")
                            .font(.rxBody)
                            .foregroundStyle(.rxInkSecondary)
                    }
                    ForEach(releases) { release in
                        ReleaseNotesView(release: release)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(RX.Space.s4)
            }
            .frame(height: 380)
            .background(
                RoundedRectangle(cornerRadius: RX.Radius.lg, style: .continuous)
                    .strokeBorder(Color.rxHairline, lineWidth: 1)
            )
        } footer: {
            Link(destination: URL(string: "https://github.com/missuo/tamio/releases")!) {
                Label("All Releases", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.rx)
            Spacer()
            Button("Done", action: close)
                .buttonStyle(.rxPrimary)
                .keyboardShortcut(.defaultAction)
        }
        .frame(width: 600)
    }
}

struct ReleaseNotesView: View {
    let release: ChangelogRelease

    var body: some View {
        VStack(alignment: .leading, spacing: RX.Space.s2) {
            HStack(alignment: .firstTextBaseline, spacing: RX.Space.s2) {
                Text(release.version == "Unreleased" ? "Unreleased" : "Tamio \(release.version)")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.rxInk)
                if let date = release.date {
                    Text(date)
                        .font(.rxHelp.monospacedDigit())
                        .foregroundStyle(.rxInkSecondary)
                }
            }
            ForEach(Array(release.blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case let .heading(text):
                    Text(text)
                        .font(.rxBodyStrong)
                        .foregroundStyle(.rxInk)
                        .padding(.top, RX.Space.s2)
                case let .bullet(text):
                    HStack(alignment: .firstTextBaseline, spacing: RX.Space.s2) {
                        Text("•").foregroundStyle(.rxInkSecondary)
                        Text(text)
                            .foregroundStyle(.rxInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.rxBody)
                case let .paragraph(text):
                    Text(text)
                        .font(.rxBody)
                        .foregroundStyle(.rxInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .textSelection(.enabled)
    }
}
