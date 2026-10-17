//
//  RDIdentity.swift
//  Tamio
//
//  Created by Lakr Aream on 2022/2/9.
//

import Foundation

public struct RDIdentityGroup: Codable, Identifiable, RDGroup {
    public typealias AssociatedType = RDIdentity

    public var id = UUID()

    public private(set) var identities: [AssociatedType] = []

    public var items: [RDIdentity] {
        get { identities }
        set { identities = newValue }
    }

    /// The identities shown in Identities and offered to every server: all
    /// but the private ones a server editor keeps for its own server.
    public var shared: [RDIdentity] {
        identities.filter { !$0.isPrivate }
    }

    public static func accepts(_ item: RDIdentity) -> Bool {
        item.hasCredentials || !item.name.isEmpty
    }
}
