//
//  AES.swift
//  PTFoundation
//
//  Created by Lakr Aream on 12/15/20.
//

import CommonCrypto
import Foundation
import Keychain

#if os(macOS) || targetEnvironment(macCatalyst)
    import IOKit
#endif

/// A keychain the app cannot reach through `SecItem`. A Mac Catalyst process
/// only sees the data-protection keychain, while the AppKit builds of Rayon kept
/// the master key in the login keychain; the app supplies this to carry the key
/// over. Set it before `AES.shared` (and so `RayonStore.shared`) is first used.
public struct LegacyKeyStore: Sendable {
    public enum ReadResult: Sendable {
        case found(String)
        /// There is no key: nothing was ever stored.
        case absent
        /// There may be a key, but it could not be read (access was denied).
        case unavailable
    }

    public let read: @Sendable () -> ReadResult
    public let write: @Sendable (String) -> Bool

    public init(read: @escaping @Sendable () -> ReadResult, write: @escaping @Sendable (String) -> Bool) {
        self.read = read
        self.write = write
    }
}

public struct AES: Sendable {
    private let key: Data
    private let iv: Data

    /// The key could not be read or saved, so it lasts for this run only.
    /// Nothing is written with such a key: it would replace data that the real
    /// key can still read.
    public private(set) var isEphemeral = false

    nonisolated(unsafe) public static var legacyKeyStore: LegacyKeyStore?

    public static let shared: AES = {
        #if DEBUG
            var keyBuilder = "fdaisohfiuhfq34hifgraskhfiarhfgui34hibrfiuef"
            #if os(macOS) || targetEnvironment(macCatalyst)
                let platformExpert = IOServiceGetMatchingService(
                    kIOMainPortDefault,
                    IOServiceMatching("IOPlatformExpertDevice")
                )
                if platformExpert > 0,
                   let serialNumber = (
                       IORegistryEntryCreateCFProperty(
                           platformExpert,
                           kIOPlatformSerialNumberKey as CFString,
                           kCFAllocatorDefault,
                           0
                       )
                       .takeUnretainedValue() as? String
                   )
                {
                    keyBuilder = serialNumber
                    IOObjectRelease(platformExpert)
                }
            #endif
            return makeEngine(key: keyBuilder + keyBuilder + keyBuilder)
        #else
            let keychainServiceID = "me.mizorewww.rayon.kcAccess"
            let masterKeyID = "me.mizorewww.rayon.MasterCrypto"
            let keychain = Keychain(service: keychainServiceID)
                .label("Rayon Master Crypto Key")
                .comment("Rayon requires a master crypto key to access your encrypted data on disk and protects your accounts")

            // Where the key was kept while the app was wiki.qaq.ray0n; read
            // when there is none under the names used now.
            let formerKeychain = Keychain(service: "wiki.qaq.rayon.kcAccess")
            let formerMasterKeyID = "wiki.qaq.rayon.MasterCrypto"

            func stored() throws -> String? {
                if let master = try keychain.getString(masterKeyID), master.count > 2 { return master }
                if let master = try? formerKeychain.getString(formerMasterKeyID), master.count > 2 { return master }
                return nil
            }
            func store(_ new: String) -> Bool {
                do {
                    try keychain.remove(masterKeyID)
                    try keychain.set(new, key: masterKeyID)
                    return true
                } catch {
                    debugPrint("AES: keychain write failed: \(error.localizedDescription)")
                    return false
                }
            }

            // A read that fails is not a missing key: the key may be there and
            // refused (the login keychain asks before handing it to a new build).
            var key: String?
            var readFailed = false
            for _ in 0 ..< 3 {
                do {
                    key = try stored()
                    readFailed = false
                    break
                } catch {
                    readFailed = true
                    debugPrint("AES: keychain access failed: \(error.localizedDescription)")
                }
            }
            if let key { return makeEngine(key: key) }

            // The key of an earlier build, kept where this one cannot look.
            if let legacy = legacyKeyStore {
                switch legacy.read() {
                case let .found(master) where master.count > 2:
                    // Copied so later launches need not ask for it again. If the
                    // copy fails the key is still good, and is fetched again.
                    if !readFailed { _ = store(master) }
                    return makeEngine(key: master)
                case .unavailable:
                    // A key exists and was not handed over. Making a new one
                    // would orphan everything saved under the old one.
                    debugPrint("AES: the stored master key is unavailable, using an ephemeral key")
                    return makeEngine(key: UUID().uuidString, ephemeral: true)
                case .found, .absent:
                    break
                }
            } else if readFailed {
                debugPrint("AES: the master key could not be read, using an ephemeral key")
                return makeEngine(key: UUID().uuidString, ephemeral: true)
            }

            // Persist before activating: a key that was never written is lost
            // on the next launch, with the data encrypted under it.
            let new = UUID().uuidString
            if (!readFailed && store(new)) || legacyKeyStore?.write(new) == true {
                return makeEngine(key: new)
            }
            // Without a persisted key, stay usable for this run only.
            debugPrint("AES: no persisted master key, falling back to an ephemeral key")
            return makeEngine(key: UUID().uuidString, ephemeral: true)
        #endif
    }()

    /// Builds an engine whose key doubles as IV. The initializer pads inputs
    /// to the required sizes, so any string of 16+ characters succeeds.
    private static func makeEngine(key: String, ephemeral: Bool = false) -> AES {
        guard var engine = AES(key: key, iv: key) else {
            preconditionFailure("unreachable: key length is sufficient")
        }
        engine.isEphemeral = ephemeral
        return engine
    }

    /// 初始化 AES 引擎
    /// - Parameters:
    ///   - initKey: 要求足够长 大于或等于 32
    ///   - initIV: 要求足够长 大于或等于 16
    internal init?(key initKey: String, iv initIV: String) {
        // 初始化密钥 核查长度要求
        if initKey.count < kCCKeySizeAES128 || initIV.count < kCCBlockSizeAES128 {
            return nil
        }
        // 修改 key 到指定长度
        var initKey = initKey
        while initKey.count < 32 { // 防止意外
            initKey += initKey
        }
        while initKey.count > 32 {
            initKey.removeLast()
        }
        guard initKey.count == kCCKeySizeAES128 || initKey.count == kCCKeySizeAES256,
              let keyData = initKey.data(using: .utf8)
        else {
            return nil
        }
        // 修改 iv 到指定长度
        var initIV = initIV
        while initIV.count < kCCBlockSizeAES128 { // 防止意外
            initIV += initIV
        }
        while initIV.count > kCCBlockSizeAES128 {
            initIV.removeLast()
        }
        guard initIV.count == kCCBlockSizeAES128, let ivData = initIV.data(using: .utf8) else {
            debugPrint("Error \(#file) \(#line): Failed to set an initial vector.")
            return nil
        }
        // 储存
        key = keyData
        iv = ivData
    }

    // MARK: - API

    public func encrypt(data: Data) -> Data? {
        crypt(data: data, option: CCOperation(kCCEncrypt))
    }

    public func decrypt(data: Data) -> Data? {
        crypt(data: data, option: CCOperation(kCCDecrypt))
    }

    // MARK: - INTERNAL

    private func crypt(data: Data, option: CCOperation) -> Data? {
        let cryptLength = data.count + kCCBlockSizeAES128
        var cryptData = Data(count: cryptLength)

        let keyLength = key.count
        let options = CCOptions(kCCOptionPKCS7Padding)

        var bytesLength = Int(0)

        let status = cryptData.withUnsafeMutableBytes { cryptBytes in
            data.withUnsafeBytes { dataBytes in
                iv.withUnsafeBytes { ivBytes in
                    key.withUnsafeBytes { keyBytes in
                        CCCrypt(option, CCAlgorithm(kCCAlgorithmAES), options, keyBytes.baseAddress, keyLength, ivBytes.baseAddress, dataBytes.baseAddress, data.count, cryptBytes.baseAddress, cryptLength, &bytesLength)
                    }
                }
            }
        }

        guard UInt32(status) == UInt32(kCCSuccess) else {
            debugPrint("Error: Failed to crypt data. Status \(status)")
            return nil
        }

        cryptData.removeSubrange(bytesLength ..< cryptData.count)
        return cryptData
    }
}
