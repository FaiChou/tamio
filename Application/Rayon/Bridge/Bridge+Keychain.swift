//
//  Bridge+Keychain.swift
//  MacBridge
//
//  The login keychain. The AppKit builds of Rayon kept the master key there, and
//  a Catalyst process cannot see it through SecItem, only through the older
//  SecKeychain calls made from AppKit code.
//

import Foundation
import Security

extension Bridge {
    func readLoginKeychain(service: String, account: String, result: (MacLegacyKeyStatus, String?) -> Void) {
        var length: UInt32 = 0
        var data: UnsafeMutableRawPointer?
        let status = SecKeychainFindGenericPassword(
            nil,
            UInt32(service.utf8.count), service,
            UInt32(account.utf8.count), account,
            &length, &data, nil
        )
        defer { if let data { SecKeychainItemFreeContent(nil, data) } }
        switch status {
        case errSecSuccess:
            guard let data, let value = String(data: Data(bytes: data, count: Int(length)), encoding: .utf8) else {
                result(.unavailable, nil)
                return
            }
            result(.found, value)
        case errSecItemNotFound:
            result(.absent, nil)
        default:
            // Denied, cancelled, or a locked keychain: the item may well be there.
            result(.unavailable, nil)
        }
    }

    func writeLoginKeychain(service: String, account: String, label: String, value: String) -> Bool {
        var item: SecKeychainItem?
        let status = SecKeychainAddGenericPassword(
            nil,
            UInt32(service.utf8.count), service,
            UInt32(account.utf8.count), account,
            UInt32(value.utf8.count), value,
            &item
        )
        guard status == errSecSuccess else { return false }
        // The name the item goes by in Keychain Access.
        if let item {
            var bytes = Array(label.utf8)
            bytes.withUnsafeMutableBytes { buffer in
                var attribute = SecKeychainAttribute(
                    tag: SecItemAttr.labelItemAttr.rawValue,
                    length: UInt32(buffer.count),
                    data: buffer.baseAddress
                )
                withUnsafeMutablePointer(to: &attribute) { pointer in
                    var list = SecKeychainAttributeList(count: 1, attr: pointer)
                    _ = SecKeychainItemModifyAttributesAndData(item, &list, 0, nil)
                }
            }
        }
        return true
    }
}
