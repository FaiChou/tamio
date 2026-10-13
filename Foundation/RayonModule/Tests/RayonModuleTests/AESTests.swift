//
//  AESTests.swift
//  RayonModuleTests
//

@testable import RayonModule
import CommonCrypto
import XCTest

final class AESTests: XCTestCase {
    private let key = "test-master-key-0123456789abcdef"

    private var engine: AES {
        AES(key: key, iv: key)!
    }

    func testNewFormatRoundTrip() throws {
        let plain = Data("servers and identities".utf8)
        let encrypted = try XCTUnwrap(engine.encrypt(data: plain))
        XCTAssertTrue(encrypted.starts(with: Data("RGCM1".utf8)))
        XCTAssertEqual(engine.decrypt(data: encrypted), plain)
    }

    func testEncryptingTwiceProducesDifferentBytes() throws {
        let plain = Data("same input".utf8)
        let first = try XCTUnwrap(engine.encrypt(data: plain))
        let second = try XCTUnwrap(engine.encrypt(data: plain))
        XCTAssertNotEqual(first, second, "a random nonce per write")
    }

    func testTamperedCiphertextIsRefused() throws {
        var encrypted = try XCTUnwrap(engine.encrypt(data: Data("payload".utf8)))
        encrypted[encrypted.count - 1] ^= 1
        XCTAssertNil(engine.decrypt(data: encrypted))
    }

    func testLegacyCiphertextStillReads() throws {
        let plain = Data("stored before the migration".utf8)
        let legacy = try XCTUnwrap(legacyEncrypt(plain))
        XCTAssertFalse(legacy.starts(with: Data("RGCM1".utf8)))
        XCTAssertEqual(engine.decrypt(data: legacy), plain)
    }

    /// What Rayon wrote before the GCM migration: AES-CBC with PKCS7
    /// padding, the key doubling as IV.
    private func legacyEncrypt(_ data: Data) -> Data? {
        var keyString = key
        while keyString.count < 32 { keyString += keyString }
        while keyString.count > 32 { keyString.removeLast() }
        let keyData = Data(keyString.utf8)
        let ivData = Data(keyString.prefix(kCCBlockSizeAES128).utf8)

        let cryptLength = data.count + kCCBlockSizeAES128
        var cryptData = Data(count: cryptLength)
        var bytesLength = 0
        let status = cryptData.withUnsafeMutableBytes { cryptBytes in
            data.withUnsafeBytes { dataBytes in
                ivData.withUnsafeBytes { ivBytes in
                    keyData.withUnsafeBytes { keyBytes in
                        CCCrypt(
                            CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress, keyData.count, ivBytes.baseAddress,
                            dataBytes.baseAddress, data.count,
                            cryptBytes.baseAddress, cryptLength, &bytesLength
                        )
                    }
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        cryptData.removeSubrange(bytesLength ..< cryptData.count)
        return cryptData
    }
}
