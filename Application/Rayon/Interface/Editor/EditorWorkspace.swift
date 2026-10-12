//
//  EditorWorkspace.swift
//  Rayon (macOS)
//
//  The files a server has open in the editor. They are read and written over
//  the server's SFTP session (the one Files uses), so an editor lives as long
//  as that session does.
//

import Combine
import RayonEditor
import RayonModule
import SwiftUI

/// Where the caret is. Apart from the document, so moving the caret redraws
/// the status line and nothing else.
@MainActor
final class EditorCaretPosition: ObservableObject {
    @Published var value = EditorCaret(line: 1, column: 1)
}

/// One remote text file open in the editor.
@MainActor
final class EditorDocument: ObservableObject, Identifiable {
    enum Phase: Equatable {
        case loading
        case editing
        case failed(String)
    }

    nonisolated let id = UUID()
    let path: String
    private let context: FileTransferContext

    @Published private(set) var phase = Phase.loading
    @Published private(set) var isEdited = false
    @Published private(set) var saving = false
    @Published var language = EditorLanguage.plain
    let caret = EditorCaretPosition()

    /// Not published: the editor view holds what is typed, and publishing every
    /// keystroke would redraw the page around it.
    var text = "" {
        didSet {
            let edited = text != savedText
            if edited != isEdited { isEdited = edited }
        }
    }

    private var savedText = ""

    var name: String { (path as NSString).lastPathComponent }
    var folder: String { (path as NSString).deletingLastPathComponent }

    init(path: String, context: FileTransferContext) {
        self.path = path
        self.context = context
        load()
    }

    #if DEBUG
        /// A file that is already loaded, for the editor preview.
        init(path: String, context: FileTransferContext, preview: String) {
            self.path = path
            self.context = context
            savedText = preview
            text = preview
            language = EditorLanguage.detect(fileName: (path as NSString).lastPathComponent, firstLine: String(preview.prefix { $0 != "\n" }))
            phase = .editing
        }
    #endif

    /// Reads the file from the server, replacing what the editor shows.
    func load() {
        phase = .loading
        Task {
            do {
                // The server may still be connecting when a file is opened from
                // the Editor tab of a server that had nothing open.
                try await waitForConnection()
                nonisolated(unsafe) let context = context
                let loaded = try await context.readText(at: path)
                savedText = loaded
                text = loaded
                let firstLine = loaded.prefix { $0 != "\n" }
                language = EditorLanguage.detect(fileName: name, firstLine: String(firstLine))
                phase = .editing
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func save() {
        guard phase == .editing, isEdited, !saving else { return }
        let snapshot = text
        saving = true
        Task {
            defer { saving = false }
            do {
                nonisolated(unsafe) let context = context
                try await context.writeText(snapshot, to: path)
                savedText = snapshot
                isEdited = text != snapshot
                // Size and date in Files, if it shows this folder.
                if context.currentUrl.path == folder { context.loadCurrentFileList() }
            } catch {
                UIBridge.presentError(with: "Couldn't save \(name). \(error.localizedDescription)")
            }
        }
    }

    private func waitForConnection() async throws {
        var waited = 0.0
        while !context.connected, context.processConnection, !context.destroyedSession, waited < 30 {
            try await Task.sleep(nanoseconds: 150_000_000)
            waited += 0.15
        }
    }
}

/// A server's open files and the one in front.
@MainActor
final class EditorWorkspace: ObservableObject, Identifiable {
    let context: FileTransferContext
    nonisolated let id: UUID

    @Published private(set) var documents: [EditorDocument] = []
    @Published var selection: EditorDocument.ID?
    private var observers: [EditorDocument.ID: AnyCancellable] = [:]

    init(context: FileTransferContext) {
        self.context = context
        id = context.id
    }

    var current: EditorDocument? {
        documents.first { $0.id == selection }
    }

    var hasUnsavedChanges: Bool {
        documents.contains(where: \.isEdited)
    }

    /// Shows the file, opening it if it isn't open yet.
    func open(path: String) {
        if let existing = documents.first(where: { $0.path == path }) {
            selection = existing.id
            return
        }
        add(EditorDocument(path: path, context: context))
    }

    fileprivate func add(_ document: EditorDocument) {
        // The page's toolbar (Save, Reload) follows the document in front.
        observers[document.id] = document.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        documents.append(document)
        selection = document.id
    }

    func close(_ document: EditorDocument) {
        guard document.isEdited else { return remove(document) }
        UIBridge.requiresConfirmation(
            message: "Close \(document.name) without saving?",
            informative: "Your changes are lost if you don't save them.",
            confirmTitle: "Discard Changes",
            destructive: true,
            always: true
        ) { confirmed in
            MainActor.assumeIsolated {
                if confirmed { self.remove(document) }
            }
        }
    }

    private func remove(_ document: EditorDocument) {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        documents.remove(at: index)
        observers[document.id] = nil
        if selection == document.id {
            // The neighbour takes its place, as tabs do.
            selection = documents.isEmpty ? nil : documents[min(index, documents.count - 1)].id
        }
    }
}

/// Every server's editor, by the id of its SFTP session.
final class EditorCenter: ObservableObject {
    nonisolated(unsafe) static let shared = EditorCenter()

    @Published private(set) var workspaces: [EditorWorkspace] = []
    private var cancellable: AnyCancellable?

    private init() {
        // An editor ends with its SFTP session.
        cancellable = FileTransferManager.shared.$transfers.sink { [weak self] transfers in
            guard let self else { return }
            let alive = Set(transfers.map(\.id))
            if self.workspaces.contains(where: { !alive.contains($0.id) }) {
                self.workspaces.removeAll { !alive.contains($0.id) }
            }
        }
    }

    @MainActor
    func workspace(for context: FileTransferContext) -> EditorWorkspace {
        if let existing = workspaces.first(where: { $0.id == context.id }) { return existing }
        let workspace = EditorWorkspace(context: context)
        workspaces.append(workspace)
        return workspace
    }

    func end(_ id: UUID) {
        workspaces.removeAll { $0.id == id }
    }
}

enum EditorSessionActions {
    /// Closes a server's editor; its Files page stays.
    @MainActor
    static func close(_ workspace: EditorWorkspace) {
        guard workspace.hasUnsavedChanges else { return EditorCenter.shared.end(workspace.id) }
        UIBridge.requiresConfirmation(
            message: "Close the editor on \(workspace.context.machine.name)?",
            informative: "Some files have changes that are not saved. They are lost if you close the editor.",
            confirmTitle: "Discard Changes",
            destructive: true,
            always: true
        ) { confirmed in
            if confirmed { EditorCenter.shared.end(workspace.id) }
        }
    }
}

#if DEBUG
    extension AppRouter {
        /// The editor on sample files, with no server: launch a debug build with
        /// RAYON_PREVIEW_EDITOR=1 to check highlighting and layout.
        @MainActor
        func showEditorPreview() {
            let machine = RDMachine(remoteAddress: "203.0.113.10", remotePort: "22", name: "web-01")
            let context = FileTransferContext(machine: machine)
            FileTransferManager.shared.transfers.append(context)
            let workspace = EditorCenter.shared.workspace(for: context)
            workspace.addPreview(path: "/etc/nginx/nginx.conf", text: """
            user www-data;
            worker_processes auto;

            http {
                sendfile on;
                keepalive_timeout 65;
                include /etc/nginx/conf.d/*.conf;
            }
            """)
            workspace.addPreview(path: "/opt/web/config.json", text: """
            {
              "port": 8080,
              "workers": 4,
              "logLevel": "info",
              "upstreams": ["10.0.0.11", "10.0.0.12"]
            }
            """)
            workspace.addPreview(path: "/usr/local/bin/rotate-logs.sh", text: """
            #!/usr/bin/env bash
            # Rotate logs and restart the service.
            set -euo pipefail

            LOG_DIR="/var/log/web"
            KEEP=7

            rotate() {
                local file="$1"
                if [[ -s "$file" ]]; then
                    mv "$file" "$file.$(date +%Y%m%d)"
                fi
            }

            for log in "$LOG_DIR"/*.log; do
                rotate "$log"
            done
            find "$LOG_DIR" -name '*.log.*' -mtime +"$KEEP" -delete
            systemctl restart web.service   # pick up new log handles
            """)
            route = .editor(context.id)
        }
    }

    extension EditorWorkspace {
        func addPreview(path: String, text: String) {
            add(EditorDocument(path: path, context: context, preview: text))
        }
    }
#endif
