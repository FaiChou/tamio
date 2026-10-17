//
//  EditSnippetView.swift
//  TamioMobile
//
//  Created by Lakr Aream on 2022/3/3.
//

import CodeEditorUI
import TamioModule
import SwiftUI
import SymbolPicker

struct EditSnippetView: View {
    @Environment(\.dismiss) private var dismiss

    let inEditWith: UUID?

    init(requestSnippet: UUID? = nil) {
        inEditWith = requestSnippet
    }

    // Pinned in state so the editor's factory and its view stay paired while
    // SwiftUI recreates this view.
    @State var editor = SCodeEditor()

    @State var initializedOnce = false

    @State var name: String = ""
    @State var group: String = ""
    @State var code: String = ""
    @State var comment: String = ""
    @State var avatar: String = ""

    @State var openSymbolPicker: Bool = false

    var body: some View {
        List {
            Section {
                TextField("Name", text: $name)
                Button {
                    openSymbolPicker = true
                } label: {
                    if avatar.isEmpty {
                        Text("Select SF Symbol")
                    } else {
                        Label("Select SF Symbol", systemImage: avatar.isEmpty ? "square.dashed" : avatar)
                    }
                }
                TextField("Group", text: $group)
                TextField("Comment", text: $comment)
            } header: {
                RXSectionHeader("Name")
            }

            Section {
                editor
                    .onContentChange { code = $0 }
                    .frame(height: 250)
            } header: {
                RXSectionHeader("Code")
            }

            if let identity = inEditWith {
                Section {
                    Button {
                        UIBridge.requiresConfirmation(
                            message: "Delete this snippet?"
                        ) { confirmed in
                            if confirmed {
                                TamioStore.shared.snippetGroup.delete(identity)
                                dismiss()
                            }
                        }
                    } label: {
                        Label("Delete Snippet", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .onAppear {
            if initializedOnce { return }
            initializedOnce = true
            // Writing the fields synchronously in onAppear races the
            // sheet's own first update: on iOS 15 the values could be
            // swallowed and the form stayed empty. One runloop hop lets
            // the current update cycle finish before the state changes.
            DispatchQueue.main.async {
                if let edit = inEditWith {
                    let read = TamioStore.shared.snippetGroup[edit]
                    name = read.name
                    group = read.group
                    code = read.code
                    comment = read.comment
                    avatar = read.getSFAvatar()
                }
                if comment.isEmpty {
                    comment = "Created at: " + Date().formatted()
                }
                if code.isEmpty {
                    editor.setDocumentData("#!/bin/bash\n\n")
                } else {
                    editor.setDocumentData(code)
                }
            }
        }
        .sheet(isPresented: $openSymbolPicker, onDismiss: nil) {
            SymbolPicker(symbol: $avatar)
        }
        .rxGroupedList()
        .navigationTitle(inEditWith == nil ? "New Snippet" : "Edit Snippet")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    completeSheet()
                } label: {
                    Text("Save").bold()
                }
            }
        }
    }

    func completeSheet() {
        guard !name.isEmpty else {
            UIBridge.presentError(with: "Empty Name")
            return
        }

        let id = inEditWith ?? UUID()

        var newSnippet = RDSnippet(
            id: id,
            name: name,
            group: group,
            code: code,
            comment: comment,
            attachment: [:]
        )
        if avatar.isEmpty {
            newSnippet.clearSFAvatar()
        } else {
            newSnippet.setSFAvatar(sfSymbol: avatar)
        }

        TamioStore.shared.snippetGroup.insert(newSnippet)

        dismiss()
    }
}

struct EditSnippetView_Previews: PreviewProvider {
    static var previews: some View {
        createPreview { AnyView(EditSnippetView()) }
    }
}
