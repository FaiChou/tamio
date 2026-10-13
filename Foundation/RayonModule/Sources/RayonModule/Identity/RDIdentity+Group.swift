//
//  RDIdentity.swift
//  Rayon
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

    public static func accepts(_ item: RDIdentity) -> Bool {
        !item.username.isEmpty
    }
}
