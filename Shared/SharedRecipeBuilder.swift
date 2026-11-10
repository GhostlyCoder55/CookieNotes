//
//  SharedRecipeBuilder.swift
//  CookieNotes
//

import Foundation

enum SharedRecipeBuilder {
    private static func isFrench(defaults: UserDefaults?) -> Bool {
        let code: String?
        if let defaults {
            code = defaults.string(forKey: "cookienotes.appLanguage")
        } else {
            code = UserDefaults(suiteName: "group.com.gc.CookieNotes")?.string(forKey: "cookienotes.appLanguage")
                ?? UserDefaults.standard.string(forKey: "cookienotes.appLanguage")
        }
        return code?.hasPrefix("fr") == true
    }

    static func draft(from payload: SharedRecipePayload, defaults: UserDefaults? = nil) -> RecipeDraft {
        let parsed = RecipeTextParser.parse(payload.text)
        let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = RecipeSanitizer.webURL(payload.url) ?? ""
        let useFrench = isFrench(defaults: defaults)

        var name = title.isEmpty ? parsed.name : title
        if name.isEmpty || RecipeSanitizer.webURL(name) != nil {
            if let host = URL(string: source)?.host() {
                name = host
            }
        }
        if name.isEmpty {
            name = useFrench ? "Recette enregistrée" : "Saved recipe"
        }

        var notes = parsed.notes
        if parsed.ingredients.isEmpty && parsed.instructions.isEmpty && notes.isEmpty && !source.isEmpty {
            notes = useFrench
                ? "Enregistrée depuis le Web. Ajoutez les ingrédients et les étapes quand vous êtes prêt."
                : "Saved from the web. Add the ingredients and steps when you're ready."
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
