//
//  RDMachine.swift
//  Rayon
//
//  Created by Lakr Aream on 2022/2/8.
//

import Foundation

public struct RDMachineGroup: Codable, Identifiable, Equatable, RDGroup {
    public typealias AssociatedType = RDMachine

    public var id = UUID()

    public private(set) var machines: [AssociatedType] = []

    public var items: [RDMachine] {
        get { machines }
        set { machines = newValue }
    }

    public static func accepts(_ item: RDMachine) -> Bool {
        item.isNotPlaceholder()
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.machines == rhs.machines
    }
}
