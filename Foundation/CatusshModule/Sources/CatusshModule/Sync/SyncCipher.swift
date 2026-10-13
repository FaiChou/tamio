//
//  SyncCipher.swift
//  CatusshModule
//
//  What iCloud holds is sealed on the device: AES-256-GCM under a key that
//  only the passphrase gives (PBKDF2-HMAC-SHA256). Apple stores bytes it
//  cannot read.
//

import CommonCrypto
import CryptoKit
import Foundation

/// The stored form: how the key was derived, and the sealed document.
struct SyncEnvelope: Codable {
    static let currentVersion = 1

    var version = SyncEnvelope.currentVersion
    var salt: Data
    var rounds: Int
    /// Nonce, ciphertext and tag.
    var sealed: Data
}

enum SyncCipher {
    /// Why an envelope did not open.
    enum OpenError: Error {
        /// The key does not fit: the passphrase is wrong.
        case wrongPassphrase
        /// It opened, but what is inside is damaged.
        case corruptedData
    }

    /// A key, and the salt and rounds it came from.
    struct Key: Sendable {
        let salt: Data
        let rounds: Int
        let key: SymmetricKey
    }

    static let rounds = 600_000
    /// Fewer rounds than this are refused: whoever can write to the store
    /// could otherwise have the next upload sealed under a weak key.
    static let minimumRounds = 100_000
    static let maximumRounds = 10_000_000

    static let context = Data("me.mizorewww.rayon.sync.v1".utf8)

    static func newSalt() -> Data {
        Data((0 ..< 16).map { _ in UInt8.random(in: .min ... .max) })
    }

    static func key(passphrase: String, salt: Data, rounds: Int) -> Key {
        var derived = [UInt8](repeating: 0, count: 32)
        let password = Array(passphrase.precomposedStringWithCanonicalMapping.utf8)
        let status = salt.withUnsafeBytes { saltBytes in
            password.withUnsafeBytes { passwordBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBytes.bindMemory(to: CChar.self).baseAddress, password.count,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(rounds),
                    &derived, derived.count
                )
            }
        }
        precondition(status == kCCSuccess, "PBKDF2 takes any password and salt")
        return Key(salt: salt, rounds: rounds, key: SymmetricKey(data: derived))
    }

    static func seal(_ plain: Data, with key: Key) throws -> Data {
        let packed = try (plain as NSData).compressed(using: .zlib) as Data
        let box = try CryptoKit.AES.GCM.seal(packed, using: key.key, authenticating: context)
        guard let sealed = box.combined else { throw CocoaError(.coderInvalidValue) }
        return try JSONEncoder().encode(SyncEnvelope(salt: key.salt, rounds: key.rounds, sealed: sealed))
    }

    /// Throws `OpenError.wrongPassphrase` when the key does not open it,
    /// `OpenError.corruptedData` when what it opened is damaged.
    static func open(_ envelope: SyncEnvelope, with key: Key) throws -> Data {
        guard let box = try? CryptoKit.AES.GCM.SealedBox(combined: envelope.sealed),
              let packed = try? CryptoKit.AES.GCM.open(box, using: key.key, authenticating: context)
        else { throw OpenError.wrongPassphrase }
        guard let plain = try? (packed as NSData).decompressed(using: .zlib) as Data else {
            throw OpenError.corruptedData
        }
        return plain
    }
}
