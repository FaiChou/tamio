//
//  Bridge+Dialogs.swift
//  MacBridge
//

import AppKit

extension Bridge {
    private var sheetParent: NSWindow? {
        if let key = NSApp.keyWindow, ordinaryWindows.contains(key) { return key }
        return ordinaryWindows.first { $0.isVisible }
    }

    func alert(
        message: String,
        informative: String?,
        buttons: [String],
        destructiveFirstButton: Bool,
        textField: String?,
        completion: ((Int, String?) -> Void)?
    ) {
        let alert = NSAlert()
        alert.messageText = message
        if let informative { alert.informativeText = informative }
        for (index, title) in buttons.enumerated() {
            let button = alert.addButton(withTitle: title)
            if index == 0 { button.hasDestructiveAction = destructiveFirstButton }
        }
        var field: NSTextField?
        if let textField {
            // As wide as its text (a path, often), within reason; past that it
            // wraps onto more lines, so all of it shows.
            let input = NSTextField(string: textField)
            input.font = .systemFont(ofSize: NSFont.systemFontSize)
            input.cell?.wraps = true
            input.cell?.isScrollable = false
            input.usesSingleLineMode = false
            input.lineBreakMode = .byCharWrapping
            let textWidth = (textField as NSString).size(withAttributes: [.font: input.font as Any]).width
            let width = min(560, max(320, ceil(textWidth) + 16))
            let height = input.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: width, height: .greatestFiniteMagnitude)).height ?? 24
            input.frame = NSRect(x: 0, y: 0, width: width, height: max(24, ceil(height)))
            alert.accessoryView = input
            alert.layout()
            alert.window.initialFirstResponder = input
            field = input
        }
        let finish: (NSApplication.ModalResponse) -> Void = { response in
            let index = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
            completion?(index, field?.stringValue)
        }
        if let parent = sheetParent {
            alert.beginSheetModal(for: parent, completionHandler: finish)
        } else {
            finish(alert.runModal())
        }
    }

    func openPanel(
        message: String?,
        prompt: String?,
        directory: URL?,
        canChooseFiles: Bool,
        canChooseDirectories: Bool,
        allowsMultipleSelection: Bool,
        canCreateDirectories: Bool,
        showsHiddenFiles: Bool,
        completion: @escaping ([URL]) -> Void
    ) {
        let panel = NSOpenPanel()
        if let message { panel.message = message }
        if let prompt { panel.prompt = prompt }
        if let directory { panel.directoryURL = directory }
        panel.canChooseFiles = canChooseFiles
        panel.canChooseDirectories = canChooseDirectories
        panel.allowsMultipleSelection = allowsMultipleSelection
        panel.canCreateDirectories = canCreateDirectories
        panel.showsHiddenFiles = showsHiddenFiles
        let finish: (NSApplication.ModalResponse) -> Void = { response in
            completion(response == .OK ? panel.urls : [])
        }
        if let parent = sheetParent {
            panel.beginSheetModal(for: parent, completionHandler: finish)
        } else {
            finish(panel.runModal())
        }
    }
}
