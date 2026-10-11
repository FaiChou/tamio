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
    /// Nil only if the bundle is missing from the app, which a build never is.
    nonisolated(unsafe) static let bridge: MacBridging? = {
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
    }()

    /// Lets the store find the master key the AppKit builds of Rayon kept in
    /// the login keychain. Call before `RayonStore.shared` is first used.
    static func installLegacyKeyStore() {
        let service = "wiki.qaq.rayon.kcAccess"
        let account = "wiki.qaq.rayon.MasterCrypto"
        AES.legacyKeyStore = LegacyKeyStore(
            read: {
                guard let bridge else { return .unavailable }
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
            },
            write: { key in
                bridge?.writeLoginKeychain(service: service, account: account, label: "Rayon Master Crypto Key", value: key) ?? false
            }
        )
    }
}
