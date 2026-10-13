//
//  RayonStore.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/8.
//

import Combine
import Foundation
import NSRemoteShell
import PropertyWrapper
#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

public class RayonStore: ObservableObject {
    public init() {
        defer {
            debugPrint("RayonStore init completed")
        }

        // Before anything is read: the settings may still be under their
        // former names.
        Self.adoptFormerDefaults()

        // bool(forKey:) also reads "YES"/"1" from the argument domain
        // (`-licenseAgreed YES`), and is false when the key is missing.
        licenseAgreed = UserDefaults.standard.bool(forKey: UserDefaultKey.licenseAgreed.rawValue)
        storeRecent = UDStoreRecent
        saveTemporarySession = UDSaveTemporarySession
        timeout = UDTimeout
        reducedViewEffects = UDReducedViewEffects
        disableConformation = UDDisableConformation
        monitorInterval = UDMonitorInterval
        terminalFontSize = UDTerminalFontSize
        if timeout <= 0 { timeout = 5 }

        if let read = readEncryptedDefault(
            from: .identityGroupEncrypted,
            identityGroup.self
        ) {
            identityGroup = read
        }
        if let read = readEncryptedDefault(
            from: .machineGroupEncrypted,
            machineGroup.self
        ) {
            machineGroup = read
        }
        if let read = readEncryptedDefault(
            from: .machineRedacted,
            machineRedacted.self
        ) {
            machineRedacted = read
        }
        if let read = readEncryptedDefault(
            from: .snippetGroupEncrypted,
            snippetGroup.self
        ) {
            snippetGroup = read
        }
        if let read = readEncryptedDefault(
            from: .recentRecordEncrypted,
            recentRecord.self
        ) {
            recentRecord = read
        }
        if let read = readEncryptedDefault(
            from: .openInterfaceAutomatically,
            openInterfaceAutomatically.self
        ) {
            openInterfaceAutomatically = read
        }
        if let read = readEncryptedDefault(
            from: .portForwardEncrypted,
            portForwardGroup.self
        ) {
            portForwardGroup = read
        }

        // Storing is debounced; leaving the foreground writes what is
        // still waiting.
        #if canImport(UIKit)
            observers.append(NotificationCenter.default.addObserver(
                forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                self?.flushPendingWrites()
            })
        #elseif canImport(AppKit)
            observers.append(NotificationCenter.default.addObserver(
                forName: NSApplication.willResignActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                self?.flushPendingWrites()
            })
        #endif
    }

    private var observers: [NSObjectProtocol] = []

    // Preserve legacy access from the existing UI and worker queues.
    nonisolated(unsafe) public static let shared = RayonStore()

    @Published public var licenseAgreed: Bool = false {
        didSet {
            storeDefault(to: .licenseAgreed, with: licenseAgreed)
        }
    }

    @Published public var globalProgressInPresent: Bool = false
    public var globalProgressCount: Int = 0 {
        didSet {
            if globalProgressCount == 0 {
                globalProgressInPresent = false
            } else {
                globalProgressInPresent = true
            }
        }
    }

    @UserDefaultsWrapper(key: "me.mizorewww.rayon.timeout", defaultValue: 5)
    private var UDTimeout: Int
    @Published public var timeout: Int = 0 {
        didSet {
            UDTimeout = timeout
        }
    }

    @UserDefaultsWrapper(key: "me.mizorewww.rayon.monitorInterval", defaultValue: 3)
    private var UDMonitorInterval: Int
    @Published public var monitorInterval: Int = 0 {
        didSet {
            UDMonitorInterval = monitorInterval
        }
    }

    public var timeoutNumber: NSNumber {
        NSNumber(value: timeout)
    }

    @Published public var openInterfaceAutomatically: Bool = true {
        didSet {
            storeEncryptedDefault(
                to: .openInterfaceAutomatically,
                with: openInterfaceAutomatically
            )
        }
    }

    @Published public var identityGroup: RDIdentityGroup = .init() {
        didSet {
            storeEncryptedDefault(
                to: .identityGroupEncrypted,
                with: identityGroup
            )
        }
    }

    public var identityGroupForAutoAuth: [RDIdentity] {
        identityGroup
            .identities
            .filter(\.authenticAutomatically)
            // make sure not to reopen too many times
            .sorted { $0.username < $1.username }
    }

    @Published public var machineRedacted: RDMachine.RedactedLevel = .none {
        didSet {
            storeEncryptedDefault(
                to: .machineRedacted,
                with: machineRedacted
            )
        }
    }

    @Published public var machineGroup: RDMachineGroup = .init() {
        didSet {
            storeEncryptedDefault(
                to: .machineGroupEncrypted,
                with: machineGroup
            )
        }
    }

    @UserDefaultsWrapper(key: "me.mizorewww.rayon.saveTemporarySession", defaultValue: true)
    private var UDSaveTemporarySession: Bool

    @Published public var saveTemporarySession: Bool = false {
        didSet {
            UDSaveTemporarySession = saveTemporarySession
        }
    }

    @UserDefaultsWrapper(key: "me.mizorewww.rayon.storeRecent", defaultValue: true)
    private var UDStoreRecent: Bool

    @Published public var storeRecent: Bool = false {
        didSet {
            UDStoreRecent = storeRecent
            if !storeRecent {
                recentRecord = []
            }
        }
    }

    @UserDefaultsWrapper(key: "me.mizorewww.rayon.reducedViewEffects", defaultValue: false)
    private var UDReducedViewEffects: Bool

    @Published public var reducedViewEffects: Bool = false {
        didSet {
            UDReducedViewEffects = reducedViewEffects
        }
    }

    @UserDefaultsWrapper(key: "me.mizorewww.rayon.disableConformation", defaultValue: false)
    private var UDDisableConformation: Bool

    @Published public var disableConformation: Bool = false {
        didSet {
            UDDisableConformation = disableConformation
        }
    }

    @UserDefaultsWrapper(key: "me.mizorewww.rayon.maxRecentRecordCount", defaultValue: 8)
    public var maxRecentRecordCount: Int

    @Published public var recentRecord: [RecentConnection] = [] {
        didSet {
            storeEncryptedDefault(
                to: .recentRecordEncrypted,
                with: recentRecord
            )
        }
    }

    @UserDefaultsWrapper(key: "me.mizorewww.rayon.terminalFontSize", defaultValue: 14)
    public var UDTerminalFontSize: Int

    @Published public var terminalFontSize: Int = 14 {
        didSet {
            UDTerminalFontSize = terminalFontSize
        }
    }

    @Published public var snippetGroup: RDSnippetGroup = .init() {
        didSet {
            storeEncryptedDefault(
                to: .snippetGroupEncrypted,
                with: snippetGroup
            )
        }
    }

    @Published public var portForwardGroup: RDPortForwardGroup = .init() {
        didSet {
            storeEncryptedDefault(
                to: .portForwardEncrypted,
                with: portForwardGroup
            )
        }
    }
}
