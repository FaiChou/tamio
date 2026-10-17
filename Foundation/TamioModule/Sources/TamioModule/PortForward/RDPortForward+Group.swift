//
//  File.swift
//
//
//  Created by Lakr Aream on 2022/3/10.
//

import Foundation

public struct RDPortForwardGroup: Codable, Identifiable, Equatable, RDGroup {
    public typealias AssociatedType = RDPortForward

    public var id = UUID()

    public private(set) var forwards: [AssociatedType] = []

    public var items: [RDPortForward] {
        get { forwards }
        set { forwards = newValue }
    }

    public static func accepts(_: RDPortForward) -> Bool {
        true
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        // Compare content, not the group identity: edits to a forward
        // must be observable so SwiftUI refreshes.
        lhs.forwards == rhs.forwards
    }
}
