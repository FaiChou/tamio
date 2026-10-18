//
//  asc-profile.swift
//
//  Writes the Mac app's Developer ID provisioning profile, made through the
//  App Store Connect API: what Xcode's automatic signing does, without Xcode.
//  The app id is registered when there is none, with iCloud on, and the
//  profile is made again when it has expired or lacks a certificate.
//
//  Usage:
//    swift Workflow/Scripts/asc-profile.swift <key.p8> <key id> <issuer id> <bundle id> <output>
//
//  The profile holds every Developer ID Application certificate of the team,
//  so any of them can sign with it.
//

import CryptoKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 6 else {
    FileHandle.standardError.write(Data("usage: asc-profile.swift <key.p8> <key id> <issuer id> <bundle id> <output>\n".utf8))
    exit(2)
}
let (keyPath, keyID, issuerID, bundleID, output) = (arguments[1], arguments[2], arguments[3], arguments[4], arguments[5])
let profileName = "\(bundleID) Mac Developer ID"
let profileType = "MAC_APP_DIRECT"

struct Failure: Error, CustomStringConvertible {
    let description: String
}

func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

func token() throws -> String {
    let key = try P256.Signing.PrivateKey(pemRepresentation: String(contentsOfFile: keyPath, encoding: .utf8))
    let now = Int(Date().timeIntervalSince1970)
    let header = base64URL(try JSONSerialization.data(withJSONObject: ["alg": "ES256", "kid": keyID, "typ": "JWT"]))
    let claims = base64URL(try JSONSerialization.data(withJSONObject: [
        "iss": issuerID, "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1",
    ]))
    let signature = base64URL(try key.signature(for: Data("\(header).\(claims)".utf8)).rawRepresentation)
    return "\(header).\(claims).\(signature)"
}

let bearer = try token()

typealias Object = [String: Any]

@discardableResult
func call(_ method: String, _ path: String, _ body: Object? = nil) throws -> Object {
    var request = URLRequest(url: URL(string: "https://api.appstoreconnect.apple.com/v1/\(path)")!)
    request.httpMethod = method
    request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
    if let body {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
    }
    let semaphore = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var result: (Data?, URLResponse?, Error?)
    URLSession.shared.dataTask(with: request) { result = ($0, $1, $2); semaphore.signal() }.resume()
    semaphore.wait()
    if let error = result.2 { throw error }
    let status = (result.1 as? HTTPURLResponse)?.statusCode ?? 0
    let object = result.0.flatMap { try? JSONSerialization.jsonObject(with: $0) as? Object } ?? [:]
    guard (200 ..< 300).contains(status) else {
        let errors = (object["errors"] as? [Object] ?? []).map { "\($0["title"] ?? ""): \($0["detail"] ?? "")" }
        throw Failure(description: "\(method) \(path.split(separator: "?")[0]) → \(status) \(errors.joined(separator: "; "))")
    }
    return object
}

func list(_ path: String) throws -> [Object] {
    try call("GET", path)["data"] as? [Object] ?? []
}

func attributes(_ object: Object) -> Object { object["attributes"] as? Object ?? [:] }
func id(_ object: Object) -> String { object["id"] as? String ?? "" }

func log(_ text: String) { FileHandle.standardError.write(Data((text + "\n").utf8)) }

do {
    // The app id, with iCloud on.
    let query = bundleID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
    var bundle = try list("bundleIds?filter%5Bidentifier%5D=\(query)&limit=200")
        .first { attributes($0)["identifier"] as? String == bundleID }
    if bundle == nil {
        log("Registering the app id \(bundleID)")
        bundle = try call("POST", "bundleIds", ["data": ["type": "bundleIds", "attributes": [
            "identifier": bundleID, "name": "Tamio", "platform": "UNIVERSAL",
        ]]])["data"] as? Object
    }
    guard let bundle else { throw Failure(description: "The app id \(bundleID) could not be registered.") }
    let capabilities = try list("bundleIds/\(id(bundle))/bundleIdCapabilities")
        .compactMap { attributes($0)["capabilityType"] as? String }
    if !capabilities.contains("ICLOUD") {
        log("Turning on iCloud for \(bundleID)")
        try call("POST", "bundleIdCapabilities", ["data": [
            "type": "bundleIdCapabilities",
            "attributes": ["capabilityType": "ICLOUD", "settings": [[
                "key": "ICLOUD_VERSION", "options": [["key": "XCODE_6", "enabled": true]],
            ]]],
            "relationships": ["bundleId": ["data": ["type": "bundleIds", "id": id(bundle)]]],
        ]])
    }

    // The team's Developer ID Application certificates.
    let dates = ISO8601DateFormatter()
    dates.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let certificates = try list("certificates?limit=200").filter { certificate in
        let type = attributes(certificate)["certificateType"] as? String ?? ""
        let expiry = (attributes(certificate)["expirationDate"] as? String).flatMap(dates.date)
        return type.hasPrefix("DEVELOPER_ID_APPLICATION") && (expiry ?? .distantPast) > Date()
    }
    guard !certificates.isEmpty else { throw Failure(description: "The team has no Developer ID Application certificate.") }
    let wanted = Set(certificates.map(id))

    // The profile, made again when it does not hold them all.
    var content: String?
    for profile in try list("bundleIds/\(id(bundle))/profiles?limit=200")
    where attributes(profile)["name"] as? String == profileName {
        let held = Set(try list("profiles/\(id(profile))/certificates?limit=200").map(id))
        if attributes(profile)["profileState"] as? String == "ACTIVE", held == wanted, content == nil {
            content = attributes(profile)["profileContent"] as? String
        } else {
            log("Removing the outdated profile \(id(profile))")
            try call("DELETE", "profiles/\(id(profile))")
        }
    }
    if content == nil {
        log("Making the profile \(profileName)")
        let made = try call("POST", "profiles", ["data": [
            "type": "profiles",
            "attributes": ["name": profileName, "profileType": profileType],
            "relationships": [
                "bundleId": ["data": ["type": "bundleIds", "id": id(bundle)]],
                "certificates": ["data": wanted.map { ["type": "certificates", "id": $0] }],
            ],
        ]])["data"] as? Object
        content = made.flatMap { attributes($0)["profileContent"] as? String }
    }
    guard let content, let data = Data(base64Encoded: content) else {
        throw Failure(description: "The profile came back empty.")
    }
    try data.write(to: URL(fileURLWithPath: output))
    log("Wrote \(profileName)")
} catch {
    log("error: \(error)")
    exit(1)
}
