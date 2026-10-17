//
//  SSHKeyGenerator.swift
//  TamioModule
//
//  Makes new Ed25519 key pairs in OpenSSH's own formats: the private key as
//  "-----BEGIN OPENSSH PRIVATE KEY-----" (unencrypted, like `ssh-keygen -N ""`)
//  and the public key as one authorized_keys line.
//

import CryptoKit
import Foundation

public enum SSHKeyGenerator {
    public struct KeyPair: Sendable {
        public let privateKey: String
        public let publicKey: String
    }

    public static func ed25519(comment: String) -> KeyPair {
        let key = Curve25519.Signing.PrivateKey()
        return ed25519(seed: key.rawRepresentation, comment: comment)
    }

    /// The pair for a 32-byte seed; `check` stands in for the random check
    /// word so tests can compare with fixed output.
    static func ed25519(seed: Data, comment: String, check: UInt32 = .random(in: .min ... .max)) -> KeyPair {
        let key = try! Curve25519.Signing.PrivateKey(rawRepresentation: seed)
        let publicBytes = key.publicKey.rawRepresentation

        var publicBlob = Data()
        publicBlob.appendString("ssh-ed25519")
        publicBlob.appendString(publicBytes)

        var secret = Data()
        secret.appendUInt32(check)
        secret.appendUInt32(check)
        secret.appendString("ssh-ed25519")
        secret.appendString(publicBytes)
        // OpenSSH keeps the seed followed by the public key.
        secret.appendString(seed + publicBytes)
        secret.appendString(comment)
        var pad: UInt8 = 1
        while secret.count % 8 != 0 {
            secret.append(pad)
            pad += 1
        }

        var body = Data("openssh-key-v1".utf8)
        body.append(0)
        body.appendString("none") // cipher
        body.appendString("none") // kdf
        body.appendString(Data()) // kdf options
        body.appendUInt32(1) // keys
        body.appendString(publicBlob)
        body.appendString(secret)

        let base64 = body.base64EncodedString()
        let lines = stride(from: 0, to: base64.count, by: 70).map { offset -> String in
            let start = base64.index(base64.startIndex, offsetBy: offset)
            let end = base64.index(start, offsetBy: 70, limitedBy: base64.endIndex) ?? base64.endIndex
            return String(base64[start ..< end])
        }
        let privateKey = (["-----BEGIN OPENSSH PRIVATE KEY-----"] + lines + ["-----END OPENSSH PRIVATE KEY-----"])
            .joined(separator: "\n") + "\n"
        let publicKey = "ssh-ed25519 " + publicBlob.base64EncodedString() + (comment.isEmpty ? "" : " " + comment)
        return KeyPair(privateKey: privateKey, publicKey: publicKey)
    }
}

private extension Data {
    mutating func appendUInt32(_ value: UInt32) {
        append(contentsOf: Swift.withUnsafeBytes(of: value.bigEndian, Array.init))
    }

    /// An SSH "string": a 32-bit big-endian length, then the bytes.
    mutating func appendString(_ value: Data) {
        appendUInt32(UInt32(value.count))
        append(value)
    }

    mutating func appendString(_ value: String) {
        appendString(Data(value.utf8))
    }
}
