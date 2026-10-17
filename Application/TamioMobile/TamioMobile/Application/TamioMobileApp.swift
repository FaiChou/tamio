//
//  TamioMobileApp.swift
//  TamioMobile
//
//  Created by Lakr Aream on 2022/3/2.
//

import CodeEditorUI
import TamioModule
import SwiftUI
import TamioTerminal

@main
struct TamioMobileApp: App {
    @StateObject private var store = TamioStore.shared

    init() {
        #if DEBUG
            NSLog("\nCommand Arguments:\n" + CommandLine.arguments.joined(separator: "\n"))
        #endif

        // Shared file-transfer core lives in TamioModule; register the
        // platform UI handler it delegates to.
        FileTransferInterface.uiHandler = IOSFileTransferUIHandler()

        _ = LogRedirect.shared
        _ = TamioStore.shared
        CloudSync.shared.start()

        NSLog("static main completed")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                #if DEBUG
                .fullScreenCover(isPresented: .constant(ProcessInfo.processInfo.environment["TAMIO_PREVIEW_EDITOR"] != nil)) {
                    EditorPreviewScreen()
                }
                #endif
                .onAppear {
                    // Warm the shared WebKit process pool so the first
                    // editor (snippet or remote file) skips the cold
                    // start. SCodeEditor builds its web view lazily now,
                    // so nothing else pays this at launch; the hidden view
                    // gets a second to finish its page load before being
                    // released, or the load would be cancelled and the
                    // warm-up defeated.
                    let prewarm = CodeEditorView()
                    AppearancePreference.applyStored()
                    checkAgreement()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        withExtendedLifetime(prewarm) {
                            debugPrint("editor \(prewarm) prewarm done")
                        }
                    }
                }
                .onChange(of: store.licenseAgreed) { _ in
                    checkAgreement()
                }
        }
    }

    func checkAgreement() {
        guard !store.licenseAgreed else {
            return
        }
        let host = UIHostingController(rootView: AgreementView())
        host.preferredContentSize = preferredPopOverSize
        host.isModalInPresentation = true
        host.modalTransitionStyle = .coverVertical
        host.modalPresentationStyle = .formSheet
        // At launch the window is not in the hierarchy yet; the queue
        // replays the present once it is.
        PresentationQueue.present(next: host)
    }
}
