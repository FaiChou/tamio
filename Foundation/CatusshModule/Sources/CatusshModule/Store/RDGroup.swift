//
//  RDGroup.swift
//  CatusshModule
//
//  The insert/delete/lookup the four store groups used to carry four
//  copies of. A group keeps its own stored array — the persisted key
//  names differ and must not change — and its own placeholder rule;
//  the rest lives here once.
//

import Foundation

/// An element of a store group: identifiable, codable, and with an empty
/// init for the placeholder a lookup returns when the id is unknown.
public protocol RDGroupItem: Identifiable, Codable {
    init()
}

/// The shared behavior of the store groups (machines, identities,
/// snippets, port forwards).
public protocol RDGroup {
    associatedtype Item: RDGroupItem

    /// The group's elements; a shell forwards this to its stored array.
    var items: [Item] { get set }

    /// What insert keeps: each group refuses its own placeholder.
    static func accepts(_ item: Item) -> Bool
}

public extension RDGroup {
    var count: Int { items.count }

    mutating func insert(_ value: Item) {
        guard Self.accepts(value) else { return }
        if let index = items.firstIndex(where: { $0.id == value.id }) {
            items[index] = value
        } else {
            items.append(value)
        }
    }

    subscript(_ id: Item.ID) -> Item {
        get {
            items.first(where: { $0.id == id }) ?? .init()
        }

        set(newValue) {
            if let index = items.firstIndex(where: { $0.id == newValue.id }) {
                items[index] = newValue
            } else {
                debugPrint("setting subscript found nil when sending value, did you forget to call insert?")
            }
        }
    }

    mutating func delete(_ value: Item.ID) {
        let index = items
            .firstIndex { $0.id == value }
        if let index = index {
            items.remove(at: index)
        }
    }
}

/// A group item carrying a `group` tag; groups of such items expose
/// sorted sections.
public protocol RDGroupSectionedItem {
    var group: String { get }
}

public extension RDGroup where Item: RDGroupSectionedItem {
    var sections: [String] {
        [String](Set<String>(
            items.map(\.group)
        )).sorted()
    }

    subscript(section: String) -> [Item] {
        items.filter { $0.group == section }
    }
}
