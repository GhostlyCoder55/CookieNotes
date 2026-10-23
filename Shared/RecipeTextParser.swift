//
//  RecipeTextParser.swift
//  CookieNotes
//

import Foundation

struct ParsedRecipeText: Equatable, Sendable {
    var name: String
    var ingredients: [String]
    var instructions: [String]
    var notes: String
    var hasStructuredContent: Bool
}

/// Turns shared plain text into recipe parts. It never fetches or renders the page.
enum RecipeTextParser {
    static func parse(_ raw: String) -> ParsedRecipeText {
        let lines = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        var name = ""
        var ingredients: [String] = []
        var instructions: [String] = []
        var notes: [String] = []
        var section: Section = .preamble
        var sawHeading = false

        for line in lines where !line.isEmpty {
            if isWebURL(line) {
                continue
            }
            if let heading = heading(for: line) {
                sawHeading = true
                section = heading
                continue
            }
            if name.isEmpty && section == .preamble && !isBullet(line) && !isNumbered(line) {
                name = line
                section = .body
                continue
            }

            let cleaned = stripMarker(line)
            guard !cleaned.isEmpty else { continue }

            switch section {
            case .ingredients:
                ingredients.append(cleaned)
            case .instructions:
                instructions.append(cleaned)
            case .notes:
                notes.append(cleaned)
            case .preamble, .body:
                if isBullet(line) {
                    ingredients.append(cleaned)
                } else if isNumbered(line) {
                    instructions.append(cleaned)
                } else {
                    notes.append(cleaned)
                }
            }
        }

        return ParsedRecipeText(
            name: name,
            ingredients: ingredients,
            instructions: instructions,
            notes: notes.joined(separator: "\n"),
            hasStructuredContent: sawHeading || !ingredients.isEmpty || !instructions.isEmpty
        )
    }

    private enum Section {
        case preamble
        case body
        case ingredients
        case instructions
        case notes
    }

    private static func heading(for line: String) -> Section? {
        let normalized = line
            .trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            .lowercased()
        switch normalized {
        case "ingredient", "ingredients":
            return .ingredients
        case "instruction", "instructions", "direction", "directions", "method", "step", "steps":
            return .instructions
        case "note", "notes", "tip", "tips":
            return .notes
        default:
            return nil
        }
    }

    private static func isBullet(_ line: String) -> Bool {
        line.hasPrefix("-") || line.hasPrefix("*") || line.hasPrefix("•") || line.hasPrefix("–") || line.hasPrefix("—")
    }

    private static func isNumbered(_ line: String) -> Bool {
        line.range(of: #"^\d+[\.\)]\s+"#, options: .regularExpression) != nil
    }

    private static func stripMarker(_ line: String) -> String {
        if isNumbered(line), let range = line.range(of: #"^\d+[\.\)]\s+"#, options: .regularExpression) {
            return String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        if isBullet(line) {
            return line.dropFirst().trimmingCharacters(in: .whitespaces)
        }
        return line
    }

    private static func isWebURL(_ line: String) -> Bool {
        guard let url = URL(string: line), let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}
