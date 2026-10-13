//
//  CodeEditorUI+SwiftUI.swift
//
//
//  Created by Lakr Aream on 2022/2/6.
//

import SwiftUI

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    import AppKit

    public struct SCodeEditor: NSViewRepresentable, CodeEditor {
        public init() {}

        /// Builds the web view when SwiftUI asks for it, not when this value
        /// is initialized: SwiftUI recreates representable values on every
        /// update, and a web view is far too expensive for that. Calls made
        /// before the view exists are replayed on creation.
        final class Factory {
            var view: CodeEditorView?
            var pending: [(CodeEditorView) -> Void] = []

            func obtain() -> CodeEditorView {
                if let view { return view }
                let created = CodeEditorView()
                view = created
                for work in pending { work(created) }
                pending.removeAll()
                return created
            }

            func apply(_ work: @escaping (CodeEditorView) -> Void) {
                if let view {
                    work(view)
                } else {
                    pending.append(work)
                }
            }
        }

        nonisolated(unsafe) let factory = Factory()

        public func makeNSView(context _: Context) -> some NSView {
            factory.obtain()
        }

        public func updateNSView(_: NSViewType, context _: Context) {}

        @discardableResult
        nonisolated public func onContentChange(callback: ((String) -> Void)?) -> Self {
            factory.apply { $0.onContentChange(callback: callback) }
            return self
        }

        @discardableResult
        nonisolated public func onContentHeightChange(callback: ((Double) -> Void)?) -> Self {
            factory.apply { $0.onContentHeightChange(callback: callback) }
            return self
        }

        nonisolated public func setDocumentData(_ data: String) {
            factory.apply { $0.setDocumentData(data) }
        }

        nonisolated public func setDocumentFont(size: Int) {
            factory.apply { $0.setDocumentFont(size: size) }
        }

        nonisolated public func setDocumentLang(_ lang: String) {
            factory.apply { $0.setDocumentLang(lang) }
        }

        nonisolated public func getAvailableLang() -> [String] {
            factory.obtain().getAvailableLang()
        }

        nonisolated public func makeReadonly() {
            factory.apply { $0.makeReadonly() }
        }

        nonisolated public func requestHeightToSend() {
            factory.apply { $0.requestHeightToSend() }
        }
    }
#endif

#if canImport(UIKit)
    import UIKit

    public struct SCodeEditor: UIViewRepresentable, @preconcurrency CodeEditor {
        public init() {}

        /// Builds the web view when SwiftUI asks for it, not when this value
        /// is initialized: SwiftUI recreates representable values on every
        /// update, and a web view is far too expensive for that. Calls made
        /// before the view exists are replayed on creation.
        final class Factory {
            var view: CodeEditorView?
            var pending: [(CodeEditorView) -> Void] = []

            func obtain() -> CodeEditorView {
                if let view { return view }
                let created = CodeEditorView()
                view = created
                for work in pending { work(created) }
                pending.removeAll()
                return created
            }

            func apply(_ work: @escaping (CodeEditorView) -> Void) {
                if let view {
                    work(view)
                } else {
                    pending.append(work)
                }
            }
        }

        let factory = Factory()

        public func makeUIView(context _: Context) -> some UIView {
            factory.obtain()
        }

        public func updateUIView(_: UIViewType, context _: Context) {}

        @discardableResult
        public func onContentChange(callback: ((String) -> Void)?) -> Self {
            factory.apply { $0.onContentChange(callback: callback) }
            return self
        }

        @discardableResult
        public func onContentHeightChange(callback: ((Double) -> Void)?) -> Self {
            factory.apply { $0.onContentHeightChange(callback: callback) }
            return self
        }

        public func setDocumentData(_ data: String) {
            factory.apply { $0.setDocumentData(data) }
        }

        public func setDocumentFont(size: Int) {
            factory.apply { $0.setDocumentFont(size: size) }
        }

        public func setDocumentLang(_ lang: String) {
            factory.apply { $0.setDocumentLang(lang) }
        }

        public func getAvailableLang() -> [String] {
            factory.obtain().getAvailableLang()
        }

        public func makeReadonly() {
            factory.apply { $0.makeReadonly() }
        }

        public func requestHeightToSend() {
            factory.apply { $0.requestHeightToSend() }
        }
    }
#endif

public struct DynamicHeightCodeView: View {
    public init(loadCode: @escaping () -> (String)) {
        self.loadCode = loadCode
    }

    var loadCode: () -> (String)
    // Pinned in state so the editor's factory and its view stay paired while
    // SwiftUI recreates this value.
    @State var codeView: SCodeEditor = .init()

    @State var codeWindowHeight: Double = 200

    public var body: some View {
        codeView
            .frame(maxWidth: .infinity)
            .frame(height: codeWindowHeight)
            .disabled(true)
            .overlay(GeometryReader { r in
                Group {}.onChange(of: r.size) { _ in
                    updateHeight()
                }
            })
            .onAppear {
                codeView.makeReadonly()
                codeView.setDocumentLang("swift")
                codeView.setDocumentFont(size: 10)
                codeView.onContentHeightChange { val in
                    passingNewHeight(with: val)
                }
                codeView.setDocumentData(loadCode())
            }
    }

    func updateHeight() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            codeView.requestHeightToSend()
        }
    }

    func passingNewHeight(with val: Double) {
        if val != codeWindowHeight {
            withAnimation(.interactiveSpring()) {
                codeWindowHeight = val
            }
        }
    }
}
