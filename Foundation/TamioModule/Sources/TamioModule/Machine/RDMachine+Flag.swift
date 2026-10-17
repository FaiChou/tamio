//
//  RDMachine+Flag.swift
//  TamioModule
//
//  A country flag for servers whose label names a country: "JP Tokyo",
//  "us-sjc-docker", "KR ICN ORACLE".
//

import Foundation

public extension RDMachine {
    /// The flag of the country the label names, if it names one.
    var countryFlag: String? { Self.countryFlag(in: name) }

    /// The first word when it is a two-letter country code in any case
    /// ("jp-tokyo-1"), else the first word anywhere that is one in capitals
    /// ("Docker US SJC"), so short lower-case words are not taken for one.
    static func countryFlag(in label: String) -> String? {
        let words = label
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
        guard !words.isEmpty else { return nil }
        if let flag = flag(for: words[0]) { return flag }
        for word in words.dropFirst() where word == word.uppercased() {
            if let flag = flag(for: word) { return flag }
        }
        return nil
    }

    /// The regional-indicator pair for an ISO 3166 code; "UK" is Great Britain's.
    static func flag(for word: String) -> String? {
        guard word.count == 2, word.allSatisfy({ $0.isASCII && $0.isLetter }) else { return nil }
        var code = word.uppercased()
        if code == "UK" { code = "GB" }
        guard regionCodes.contains(code) else { return nil }
        let scalars = code.unicodeScalars.compactMap { Unicode.Scalar(0x1F1E6 - 0x41 + $0.value) }
        return String(String.UnicodeScalarView(scalars))
    }

    private static let regionCodes: Set<String> = {
        if #available(macOS 13, iOS 16, *) {
            return Set(Locale.Region.isoRegions.map(\.identifier).filter { $0.count == 2 && $0.allSatisfy(\.isLetter) })
        }
        return Set(Locale.isoRegionCodes)
    }()
}
