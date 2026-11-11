//
//  GroceryItem.swift
//  CookieNotes
//

import Foundation
import SwiftData

protocol GrocerySortable {
    var itemID: UUID { get }
    var name: String { get }
    var isChecked: Bool { get }
    var sortOrder: Int { get }
    var dateCreated: Date { get }
}

@Model
final class GroceryItem {
    var itemID: UUID = UUID()
    var name: String = ""
    var isChecked: Bool = false
    var sortOrder: Int = 0
    var dateCreated: Date = Date()
    var dateModified: Date = Date()

    init(
        itemID: UUID = UUID(),
        name: String,
        isChecked: Bool = false,
        sortOrder: Int = 0,
        dateCreated: Date = Date(),
        dateModified: Date = Date()
    ) {
        self.itemID = itemID
        self.name = name
        self.isChecked = isChecked
        self.sortOrder = sortOrder
        self.dateCreated = dateCreated
        self.dateModified = dateModified
    }
}

extension GroceryItem: GrocerySortable {}

enum GrocerySort: String, CaseIterable, Identifiable {
    static let defaultsKey = "cookienotes.grocerySortMode"

    case defaultOrder = "default"
    case uncheckedFirst = "uncheckedFirst"
    case alphabetical = "alphabetical"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .defaultOrder:
            return String.localized("Default")
        case .uncheckedFirst:
            return String.localized("Unchecked first")
        case .alphabetical:
            return String.localized("A–Z")
        }
    }
}

enum GroceryListLogic {
    static func sanitizeName(_ raw: String) -> String {
        let singleLine = raw
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(singleLine.prefix(RecipeInputLimits.name))
    }

    static func sorted<T: GrocerySortable>(_ items: [T], by sort: GrocerySort) -> [T] {
        switch sort {
        case .defaultOrder:
            return items.sorted(by: compareDefault)
        case .uncheckedFirst:
            return items.sorted { lhs, rhs in
                if lhs.isChecked != rhs.isChecked {
                    return !lhs.isChecked && rhs.isChecked
                }
                return compareDefault(lhs, rhs)
            }
        case .alphabetical:
            return items.sorted { lhs, rhs in
                let comparison = lhs.name.localizedStandardCompare(rhs.name)
                if comparison != .orderedSame {
                    return comparison == .orderedAscending
                }
                return compareDefault(lhs, rhs)
            }
        }
    }

    static func nextSortOrder<T: GrocerySortable>(in items: [T]) -> Int {
        (items.map(\.sortOrder).max() ?? -1) + 1
    }

    private static func compareDefault<T: GrocerySortable>(_ lhs: T, _ rhs: T) -> Bool {
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        if lhs.dateCreated != rhs.dateCreated {
            return lhs.dateCreated < rhs.dateCreated
        }
        return lhs.itemID.uuidString < rhs.itemID.uuidString
    }
}
