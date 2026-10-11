import Runestone
import SwiftUI
import TreeSitterBashRunestone
import TreeSitterCPPRunestone
import TreeSitterCRunestone
import TreeSitterCSSRunestone
import TreeSitterGoRunestone
import TreeSitterHTMLRunestone
import TreeSitterJavaRunestone
import TreeSitterJavaScriptRunestone
import TreeSitterJSONRunestone
import TreeSitterLuaRunestone
import TreeSitterMarkdownRunestone
import TreeSitterPerlRunestone
import TreeSitterPHPRunestone
import TreeSitterPythonRunestone
import TreeSitterRubyRunestone
import TreeSitterRustRunestone
import TreeSitterSQLRunestone
import TreeSitterSwiftRunestone
import TreeSitterTOMLRunestone
import TreeSitterTypeScriptRunestone
import TreeSitterYAMLRunestone
import UIKit

extension EditorLanguage {
    var treeSitter: TreeSitterLanguage? {
        switch self {
        case .plain: return nil
        case .bash: return .bash
        case .c: return .c
        case .cpp: return .cpp
        case .css: return .css
        case .go: return .go
        case .html: return .html
        case .java: return .java
        case .javaScript: return .javaScript
        case .json: return .json
        case .lua: return .lua
        case .markdown: return .markdown
        case .perl: return .perl
        case .php: return .php
        case .python: return .python
        case .ruby: return .ruby
        case .rust: return .rust
        case .sql: return .sql
        case .swift: return .swift
        case .toml: return .toml
        case .typeScript: return .typeScript
        case .yaml: return .yaml
        }
    }
}

/// Where the caret is, for a status line.
public struct EditorCaret: Equatable, Sendable {
    public let line: Int
    public let column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }
}

/// A code editor for one file: line numbers, syntax highlighting, matching
/// brackets and quotes, indentation that follows the file, and find (⌘F).
public struct CodeEditor: UIViewRepresentable {
    @Binding var text: String
    let language: EditorLanguage
    let wrapsLines: Bool
    let fontSize: CGFloat
    let onCaretChange: (EditorCaret) -> Void

    public init(
        text: Binding<String>,
        language: EditorLanguage,
        wrapsLines: Bool = false,
        fontSize: CGFloat = 13,
        onCaretChange: @escaping (EditorCaret) -> Void = { _ in }
    ) {
        _text = text
        self.language = language
        self.wrapsLines = wrapsLines
        self.fontSize = fontSize
        self.onCaretChange = onCaretChange
    }

    public func makeCoordinator() -> Coordinator { Coordinator(self) }

    public func makeUIView(context: Context) -> TextView {
        let view = TextView()
        view.backgroundColor = .clear
        view.editorDelegate = context.coordinator
        view.showLineNumbers = true
        view.lineSelectionDisplayType = .line
        view.gutterLeadingPadding = 12
        view.gutterTrailingPadding = 8
        view.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 8)
        view.lineHeightMultiplier = 1.2
        view.autocorrectionType = .no
        view.autocapitalizationType = .none
        view.smartQuotesType = .no
        view.smartDashesType = .no
        view.smartInsertDeleteType = .no
        view.spellCheckingType = .no
        view.characterPairs = [Pair("(", ")"), Pair("[", "]"), Pair("{", "}"), Pair("\"", "\""), Pair("'", "'")]
        view.isFindInteractionEnabled = true
        view.verticalOverscrollFactor = 0.4
        view.isLineWrappingEnabled = wrapsLines
        switch EditorIndentation.detect(in: text) {
        case .tabs: view.indentStrategy = .tab(length: 4)
        case let .spaces(width): view.indentStrategy = .space(length: width)
        }
        context.coordinator.load(text, into: view)
        return view
    }

    public func updateUIView(_ view: TextView, context: Context) {
        context.coordinator.parent = self
        if view.isLineWrappingEnabled != wrapsLines { view.isLineWrappingEnabled = wrapsLines }
        // Only text set from outside (a reload) replaces the document; typing
        // already put the view's own text in the binding.
        if text != context.coordinator.lastText {
            context.coordinator.load(text, into: view)
        }
    }

    public final class Coordinator: NSObject, TextViewDelegate {
        var parent: CodeEditor
        var lastText = ""

        init(_ parent: CodeEditor) {
            self.parent = parent
        }

        /// Parses on a background queue so a large file doesn't stall the UI.
        func load(_ text: String, into view: TextView) {
            lastText = text
            let theme = EditorTheme(size: parent.fontSize)
            let language = parent.language.treeSitter
            nonisolated(unsafe) let weakView = WeakBox(view)
            DispatchQueue.global(qos: .userInitiated).async {
                let state: TextViewState = language.map { TextViewState(text: text, theme: theme, language: $0) }
                    ?? TextViewState(text: text, theme: theme)
                nonisolated(unsafe) let ready = state
                DispatchQueue.main.async {
                    weakView.value?.setState(ready)
                }
            }
        }

        public func textViewDidChange(_ textView: TextView) {
            lastText = textView.text
            parent.text = textView.text
        }

        public func textViewDidChangeSelection(_ textView: TextView) {
            if let location = textView.textLocation(at: textView.selectedRange.location) {
                parent.onCaretChange(EditorCaret(line: location.lineNumber + 1, column: location.column + 1))
            }
        }
    }
}

private struct Pair: CharacterPair {
    let leading: String
    let trailing: String
    init(_ leading: String, _ trailing: String) {
        self.leading = leading
        self.trailing = trailing
    }
}

private final class WeakBox<Value: AnyObject> {
    weak var value: Value?
    init(_ value: Value) { self.value = value }
}
