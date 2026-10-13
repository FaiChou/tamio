//
//  RDSnippet.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/10.
//

import Foundation

public struct RDSnippetGroup: Codable, Identifiable, Equatable, RDGroup {
    public typealias AssociatedType = RDSnippet

    public var id = UUID()

    public private(set) var snippets: [AssociatedType] = []

    public var items: [RDSnippet] {
        get { snippets }
        set { snippets = newValue }
    }

    public static func accepts(_ item: RDSnippet) -> Bool {
        !item.name.isEmpty
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.snippets == rhs.snippets
    }
}
