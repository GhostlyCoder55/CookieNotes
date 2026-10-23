//
//  SharedRecipeBuilder.swift
//  CookieNotes
//

import Foundation

enum SharedRecipeBuilder {
    static func draft(from payload: SharedRecipePayload) -> RecipeDraft {
        let parsed = RecipeTextParser.parse(payload.text)
        let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = RecipeSanitizer.webURL(payload.url) ?? ""

        var name = title.isEmpty ? parsed.name : title
        if name.isEmpty || RecipeSanitizer.webURL(name) != nil {
            if let host = URL(string: source)?.host() {
                name = host
            }
        }
        if name.isEmpty {
            name = "Saved recipe"
        }

        var notes = parsed.notes
        if parsed.ingredients.isEmpty && parsed.instructions.isEmpty && notes.isEmpty && !source.isEmpty {
            notes = "Saved from the web. Add the ingredients and steps when you're ready."
        }

        return RecipeSanitizer.clean(
            RecipeDraft(
                name: name,
                ingredients: parsed.ingredients,
                instructions: parsed.instructions,
                notes: notes,
                source: source
            ),
            webSourceOnly: true
        )
    }
}
