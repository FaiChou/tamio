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
        let legacy = try XCTUnwrap(legacyEncrypt(plain, key: key))
        XCTAssertFalse(legacy.starts(with: Data("RGCM1".utf8)))
        XCTAssertEqual(engine.decrypt(data: legacy), plain)
    }

    func testSharedEngineRoundTrips() throws {
        let plain = Data("through the shared engine".utf8)
        let encrypted = try XCTUnwrap(AES.shared.encrypt(data: plain))
        XCTAssertEqual(AES.shared.decrypt(data: encrypted), plain)
    }

    func testConstantKeyCiphertextReadsThroughFallback() throws {
        let plain = Data("written by an old debug build".utf8)

        let gcm = try XCTUnwrap(legacyDebugEngine.encrypt(data: plain))
        XCTAssertNil(engine.decrypt(data: gcm), "a different key alone must not open it")
        XCTAssertEqual(engine.withLegacyDebugKeyFallback().decrypt(data: gcm), plain)

        // The legacy format has no integrity check, so it is read under
        // the constant key first.
        let cbc = try XCTUnwrap(legacyEncrypt(plain, key: AES.legacyDebugKey))
        XCTAssertEqual(engine.withLegacyDebugKeyFallback().decrypt(data: cbc), plain)
    }

    func testWritesSkipTheFallbackKey() throws {
        let fresh = Data("fresh write".utf8)
        let encrypted = try XCTUnwrap(engine.withLegacyDebugKeyFallback().encrypt(data: fresh))
        XCTAssertEqual(engine.decrypt(data: encrypted), fresh)
        XCTAssertNil(
            legacyDebugEngine.decrypt(data: encrypted),
            "writes use the new key, moving the data over on the next save"
        )
    }

    /// An engine keyed like a DEBUG build before device-specific derivation.
    private var legacyDebugEngine: AES {
        let material = AES.legacyDebugKey + AES.legacyDebugKey + AES.legacyDebugKey
        return AES(key: material, iv: material)!
    }

    /// What Rayon wrote before the GCM migration: AES-CBC with PKCS7
    /// padding, the key doubling as IV.
    private func legacyEncrypt(_ data: Data, key encryptionKey: String) -> Data? {
        var keyString = encryptionKey
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
