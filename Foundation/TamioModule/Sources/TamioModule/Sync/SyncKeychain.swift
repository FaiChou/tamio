//
//  SyncKeychain.swift
//  TamioModule
//
//  The sync passphrase in the user's iCloud Keychain, which Apple keeps
//  end-to-end encrypted and on the user's devices only. A device signed in to
//  the same iCloud finds it there, so sync turns on (and follows a changed
//  passphrase) without it being typed again. Where the keychain cannot be
//  used (a copy not signed for it), nothing is shared and the passphrase is
//  asked for, as before.
//

import Foundation
import Security

enum SyncKeychain {
    private static let service = "sb.moe.tamio.sync"
    private static let account = "passphrase"

    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any,
            kSecUseDataProtectionKeychain as String: kCFBooleanTrue as Any,
        ]
    }

    /// The passphrase another device (or this one) shared, if any.
    static func read() -> String? {
        var request = query
        request[kSecReturnData as String] = kCFBooleanTrue
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Shares `passphrase` with the user's other devices. False where the
    /// keychain cannot be used.
    @discardableResult
    static func save(_ passphrase: String) -> Bool {
        let data = Data(passphrase.utf8)
        let update = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecSuccess { return true }
        guard update == errSecItemNotFound else { return false }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        item[kSecAttrLabel as String] = "Tamio iCloud sync"
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        SecItemDelete(query as CFDictionary)
    }
}
