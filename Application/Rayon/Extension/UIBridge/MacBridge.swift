//
//  MacBridge.swift
//  Rayon
//
//  The AppKit side of the app. Rayon on the Mac is a Mac Catalyst app; what
//  UIKit cannot do there (window material, menu bar items, native alerts and
//  panels, the login keychain) is done by MacBridge.bundle, loaded here.
//

import Foundation
import RayonModule

enum Mac {
    /// The bridge, loaded once. The box is what crosses the concurrency
    /// boundary: the bridge object inside is an AppKit object used on the
    /// main thread, like the windows it manages.
    private final class BridgeBox: @unchecked Sendable {
        let value: MacBridging?
        init(_ value: MacBridging?) { self.value = value }
    }

    private static let loaded = BridgeBox(loadBridge())

    /// Nil only if the bundle is missing from the app, which a build never is.
    static var bridge: MacBridging? {
        loaded.value
    }

    private static func loadBridge() -> MacBridging? {
        guard let url = Bundle.main.builtInPlugInsURL?.appendingPathComponent("MacBridge.bundle"),
              let bundle = Bundle(url: url)
        else {
            NSLog("MacBridge.bundle is missing")
            return nil
        }
        do {
            try bundle.loadAndReturnError()
        } catch {
            NSLog("MacBridge.bundle failed to load: \(error)")
            return nil
        }
        guard let bridge = (bundle.principalClass as? NSObject.Type)?.init() as? MacBridging else {
            NSLog("MacBridge.bundle has no bridge class")
            return nil
        }
        return bridge
    }

    /// Lets the store find the master key the AppKit builds of Rayon kept in
    /// the login keychain. Call before `RayonStore.shared` is first used.
    static func installLegacyKeyStore() {
        let service = "me.mizorewww.rayon.kcAccess"
        let account = "me.mizorewww.rayon.MasterCrypto"
        // The names the key was saved under while the app was wiki.qaq.ray0n.
        // It is read from there and never written there.
        let former = (service: "wiki.qaq.rayon.kcAccess", account: "wiki.qaq.rayon.MasterCrypto")
        AES.legacyKeyStore = LegacyKeyStore(
            read: {
                guard let bridge else { return .unavailable }
                func read(_ service: String, _ account: String) -> LegacyKeyStore.ReadResult {
                    var outcome = LegacyKeyStore.ReadResult.unavailable
                    bridge.readLoginKeychain(service: service, account: account) { status, value in
                        switch status {
                        case .found: outcome = value.map { .found($0) } ?? .unavailable
                        case .absent: outcome = .absent
                        case .unavailable: outcome = .unavailable
                        @unknown default: outcome = .unavailable
                        }
                    }
                    return outcome
                }
                if case let .found(key) = read(service, account) { return .found(key) }
                return read(former.service, former.account)
            },
            write: { key in
                bridge?.writeLoginKeychain(service: service, account: account, label: "catussh Master Crypto Key", value: key) ?? false
            }
        )
    }
}
