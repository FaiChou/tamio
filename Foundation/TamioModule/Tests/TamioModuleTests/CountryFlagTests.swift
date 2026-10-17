//
//  CountryFlagTests.swift
//  TamioModuleTests
//

@testable import TamioModule
import XCTest

final class CountryFlagTests: XCTestCase {
    func testALeadingCountryCodeInAnyCaseGivesItsFlag() {
        XCTAssertEqual(RDMachine.countryFlag(in: "JP Tokyo 1"), "🇯🇵")
        XCTAssertEqual(RDMachine.countryFlag(in: "us-sjc-docker"), "🇺🇸")
        XCTAssertEqual(RDMachine.countryFlag(in: "KR ICN ORACLE"), "🇰🇷")
        XCTAssertEqual(RDMachine.countryFlag(in: "uk_london"), "🇬🇧")
    }

    func testACapitalCodeLaterInTheLabelCounts() {
        XCTAssertEqual(RDMachine.countryFlag(in: "Docker DE Frankfurt"), "🇩🇪")
        XCTAssertEqual(RDMachine.countryFlag(in: "edge-HK-02"), "🇭🇰")
    }

    func testWordsThatAreNotCountriesGiveNone() {
        XCTAssertNil(RDMachine.countryFlag(in: "DB primary"))
        XCTAssertNil(RDMachine.countryFlag(in: "prod-web-01"))
        XCTAssertNil(RDMachine.countryFlag(in: "web in tokyo"))
        XCTAssertNil(RDMachine.countryFlag(in: ""))
        XCTAssertNil(RDMachine.countryFlag(in: "127.0.0.1"))
    }
}
