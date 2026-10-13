//
//  EditPortForwardView.swift
//  mRayon
//
//  Created by Lakr Aream on 2022/3/12.
//

import RayonModule
import SwiftUI

struct EditPortForwardView: View {
    @Environment(\.dismiss) private var dismiss

    let inEditWith: (() -> (UUID?))?

    init(requestIdentity: (() -> (UUID?))? = nil) {
        inEditWith = requestIdentity
    }

    @State var initializedOnce = false

    @State var forwardOrientation: RDPortForward.ForwardOrientation = .listenLocal
    @State var bindPort: String = "3000"
    @State var targetHost: String = "127.0.0.1"
    @State var targetPort: String = "3000"
    @State var usingMachine: RDMachine.ID? = nil

    var parsedBindPort: Int? {
        guard let value = Int(bindPort), (0 ... 65535).contains(value) else { return nil }
        return value
    }

    var parsedTargetPort: Int? {
        guard let value = Int(targetPort), (0 ... 65535).contains(value) else { return nil }
        return value
    }

    var portsValid: Bool {
        parsedBindPort != nil && parsedTargetPort != nil
    }

    var generateObject: RDPortForward {
        RDPortForward(
            forwardOrientation: forwardOrientation,
            bindPort: parsedBindPort ?? 0,
            targetHost: targetHost,
            targetPort: parsedTargetPort ?? 0,
            usingMachine: usingMachine
        )
    }

    var forwardDescription: String {
        generateObject.shortDescription()
    }

    var body: some View {
        List {
            Section {
                Picker("Forward Orientation", selection: $forwardOrientation) {
                    ForEach(RDPortForward.ForwardOrientation.allCases, id: \.self) { acase in
                        Text(acase.rawValue)
                            .tag(acase)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            } header: {
                RXSectionHeader("Orientation")
            }

            Section {
                TextField("Bind Port", text: $bindPort)
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.numberPad)
            } header: {
                RXSectionHeader("Bind Port")
            }

            Section {
                TextField("Target Address", text: $targetHost)
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.never)
                TextField("Target Port", text: $targetPort)
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.numberPad)
            } header: {
                RXSectionHeader("Target Host")
            }

            Section {
                Button {
                    Task { @MainActor in
                        let machine = await RayonUtil.selectOneMachine()
                        usingMachine = machine.first
                    }
                } label: {
                    Label("Select Machine", systemImage: "arrow.right")
                        .foregroundColor(.accentColor)
                }
            } header: {
                RXSectionHeader("Machine")
            }

            Section {} footer: {
                if portsValid {
                    Text(forwardDescription)
                } else {
                    Text("Ports must be numbers between 0 and 65535")
                        .foregroundStyle(.rxDanger)
                }
            }
        }
        .onAppear {
            if initializedOnce { return }
            initializedOnce = true
            onMainThread(delay: 0.1) { // <-- SwiftUI bug here, don't remove
                if let edit = inEditWith?() {
                    let read = RayonStore.shared.portForwardGroup[edit]
                    forwardOrientation = read.forwardOrientation
                    bindPort = String(read.bindPort)
                    targetHost = read.targetHost
                    targetPort = String(read.targetPort)
                    usingMachine = read.usingMachine
                }
            }
        }
        .rxGroupedList()
        .navigationTitle("Edit Forward")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    completeSheet()
                } label: {
                    Text("Save").bold()
                }
                .disabled(!portsValid)
            }
        }
    }

    func completeSheet() {
        guard portsValid else {
            UIBridge.presentError(with: "Invalid Port")
            return
        }
        var object = generateObject
        if let edit = inEditWith?() {
            object.id = edit
        }
        RayonStore.shared.portForwardGroup.insert(object)
        dismiss()
    }
}

struct EditPortForwardView_Previews: PreviewProvider {
    static var previews: some View {
        createPreview {
            AnyView(EditPortForwardView())
        }
    }
}
