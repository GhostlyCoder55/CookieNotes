//
//  RecipeSanitizer.swift
//  CookieNotes
//

import Foundation

enum RecipeSanitizer {
    static func clean(_ draft: RecipeDraft, webSourceOnly: Bool = false) -> RecipeDraft {
        RecipeDraft(
            name: clip(singleLine(draft.name), RecipeInputLimits.name),
            ingredients: Array(
                draft.ingredients
                    .map { clip(singleLine($0), RecipeInputLimits.ingredient) }
                    .filter { !$0.isEmpty }
                    .prefix(RecipeInputLimits.ingredientCount)
            ),
            instructions: Array(
                draft.instructions
                    .map { clip($0.trimmingCharacters(in: .whitespacesAndNewlines), RecipeInputLimits.instruction) }
                    .filter { !$0.isEmpty }
                    .prefix(RecipeInputLimits.instructionCount)
            ),
            notes: clip(draft.notes.trimmingCharacters(in: .whitespacesAndNewlines), RecipeInputLimits.notes),
            source: cleanSource(draft.source, webSourceOnly: webSourceOnly),
            servings: servings(draft.servings)
        )
    }

    static func minutes(_ value: Int) -> Int {
        min(max(value, 0), RecipeInputLimits.maxMinutes)
    }

    static func servings(_ value: Int) -> Int {
        min(max(value, 0), RecipeInputLimits.maxServings)
    }

    static func webURL(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else { return nil }
        guard scheme == "https" || scheme == "http" else { return nil }
        guard url.host() != nil else { return nil }
        return String(trimmed.prefix(RecipeInputLimits.source))
    }

    private static func cleanSource(_ raw: String, webSourceOnly: Bool) -> String {
        if webSourceOnly {
            return webURL(raw) ?? ""
        }
        return clip(singleLine(raw), RecipeInputLimits.source)
    }

    private static func singleLine(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func clip(_ value: String, _ limit: Int) -> String {
        String(value.prefix(limit))
    }
}
