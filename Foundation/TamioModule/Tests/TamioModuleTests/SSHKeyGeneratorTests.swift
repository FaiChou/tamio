//
//  SSHKeyGeneratorTests.swift
//  TamioModuleTests
//

@testable import TamioModule
import XCTest

final class SSHKeyGeneratorTests: XCTestCase {
    func testOpenSSHReadsTheGeneratedKey() throws {
        let pair = SSHKeyGenerator.ed25519(comment: "tamio-test")
        XCTAssertTrue(pair.privateKey.hasPrefix("-----BEGIN OPENSSH PRIVATE KEY-----\n"))
        XCTAssertTrue(pair.privateKey.hasSuffix("-----END OPENSSH PRIVATE KEY-----\n"))
        XCTAssertTrue(pair.publicKey.hasPrefix("ssh-ed25519 "))
        XCTAssertTrue(pair.publicKey.hasSuffix(" tamio-test"))

        let keygen = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: keygen.path), "ssh-keygen is not installed")
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("tamio-key-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: file) }
        try pair.privateKey.write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)

        // ssh-keygen derives the public key from the private one; it must be
        // the one the generator wrote.
        let process = Process()
        process.executableURL = keygen
        process.arguments = ["-y", "-f", file.path]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        let derived = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(derived, pair.publicKey)
    }

    func testTheKeyTypeIsReadFromAnOpenSSHPrivateKey() {
        let pair = SSHKeyGenerator.ed25519(comment: "")
        XCTAssertEqual(RDIdentity.keyAlgorithm(publicKey: "", privateKey: pair.privateKey), "ed25519")
        XCTAssertEqual(RDIdentity.keyAlgorithm(publicKey: "", privateKey: "-----BEGIN RSA PRIVATE KEY-----\nAAAA\n"), "rsa")
        XCTAssertNil(RDIdentity.keyAlgorithm(publicKey: "", privateKey: "not a key"))
    }
}
