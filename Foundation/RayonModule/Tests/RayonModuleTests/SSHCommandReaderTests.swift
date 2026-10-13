//
//  SSHCommandReaderTests.swift
//  RayonModuleTests
//

@testable import RayonModule
import XCTest

final class SSHCommandReaderTests: XCTestCase {
    func testBasicCommand() {
        let reader = SSHCommandReader(command: "ssh root@example.com")
        XCTAssertEqual(reader?.username, "root")
        XCTAssertEqual(reader?.remoteAddress, "example.com")
        XCTAssertEqual(reader?.remotePort, "22")
    }

    func testCustomPort() {
        let reader = SSHCommandReader(command: "ssh ubuntu@10.0.0.8 -p 2222")
        XCTAssertEqual(reader?.remotePort, "2222")
        XCTAssertEqual(reader?.command, "ssh ubuntu@10.0.0.8 -p 2222")
    }

    func testRejectsAnonymousLogin() {
        XCTAssertNil(SSHCommandReader(command: "ssh example.com"))
    }

    func testRejectsMissingParts() {
        XCTAssertNil(SSHCommandReader(command: "ssh @example.com"))
        XCTAssertNil(SSHCommandReader(command: "ssh root@"))
        XCTAssertNil(SSHCommandReader(command: "ssh"))
        XCTAssertNil(SSHCommandReader(command: "mosh root@example.com"))
    }

    func testRejectsInvalidPort() {
        XCTAssertNil(SSHCommandReader(command: "ssh root@example.com -p abc"))
        XCTAssertNil(SSHCommandReader(command: "ssh root@example.com -p 70000"))
    }

    func testToleratesRepeatedSpaces() {
        let reader = SSHCommandReader(command: "ssh  root@example.com  -p  2222")
        XCTAssertEqual(reader?.username, "root")
        XCTAssertEqual(reader?.remotePort, "2222")
    }

    func testPreservesCase() {
        let reader = SSHCommandReader(command: "ssh Root@Example.COM -p 2222")
        XCTAssertEqual(reader?.username, "Root")
        XCTAssertEqual(reader?.remoteAddress, "Example.COM")
        XCTAssertEqual(reader?.remotePort, "2222")
    }

    func testUppercasePrefix() {
        let reader = SSHCommandReader(command: "SSH root@example.com")
        XCTAssertEqual(reader?.username, "root")
        XCTAssertEqual(reader?.remoteAddress, "example.com")
    }

    func testPortBeforeHost() {
        let reader = SSHCommandReader(command: "ssh -p 2222 ubuntu@10.0.0.8")
        XCTAssertEqual(reader?.username, "ubuntu")
        XCTAssertEqual(reader?.remoteAddress, "10.0.0.8")
        XCTAssertEqual(reader?.remotePort, "2222")
        XCTAssertEqual(reader?.command, "ssh ubuntu@10.0.0.8 -p 2222")
    }

    func testRejectsUnknownTokens() {
        XCTAssertNil(SSHCommandReader(command: "ssh root@example.com -v"))
        XCTAssertNil(SSHCommandReader(command: "ssh -i key.pem root@example.com"))
        XCTAssertNil(SSHCommandReader(command: "ssh -p 2222"))
        XCTAssertNil(SSHCommandReader(command: "ssh root@example.com -p"))
        XCTAssertNil(SSHCommandReader(command: "ssh -p abc root@example.com"))
    }

    func testRoundTrip() {
        let original = "ssh deploy@192.168.1.10 -p 2200"
        let reader = SSHCommandReader(command: original)
        XCTAssertEqual(reader?.command, original)
    }
}
