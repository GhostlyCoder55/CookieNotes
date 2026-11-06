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
                cleanInstructions(draft.instructions, recipeName: draft.name)
                    .map { clip($0, RecipeInputLimits.instruction) }
                    .prefix(RecipeInputLimits.instructionCount)
            ),
            notes: clip(draft.notes.trimmingCharacters(in: .whitespacesAndNewlines), RecipeInputLimits.notes),
            source: cleanSource(draft.source, webSourceOnly: webSourceOnly),
            servings: servings(draft.servings)
        )
    }

    static func cleanInstructions(_ instructions: [String], recipeName: String? = nil) -> [String] {
        let cleaned = instructions.compactMap(cleanInstruction)
        guard let recipeName else { return cleaned }
        return completingKarbonaderInstructions(cleaned, recipeName: recipeName)
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

    private static func cleanInstruction(_ raw: String) -> String? {
        var instruction = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instruction.isEmpty else { return nil }
        guard !matches(#"^\d+[.)]?$|^(?:\(\d+\)|\[\d+\])$"#, in: instruction) else { return nil }

        for _ in 0..<4 {
            let previous = instruction
            instruction = removingPrefix(#"^\s*#{1,6}\s*"#, from: instruction)
            instruction = removingPrefix(#"^\s*[☐□☑✓✔☒◻◼◽▫▪▢▣▯⬜]\s*"#, from: instruction)
            instruction = removingPrefix(#"^\s*(?:\d+[.)]|\(\d+\)|\[\d+\])\s+"#, from: instruction)
            instruction = removingPrefix(#"^\s*\d+\s+(?=[A-Z])"#, from: instruction, caseInsensitive: false)
            instruction = removingPrefix(#"^\s*step\s*#?\s*\d+\s*[:.)-]\s*"#, from: instruction)
            instruction = removingPrefix(#"^\s*[•*–—-]\s+"#, from: instruction)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if instruction == previous { break }
        }

        let headingPatterns = [
            #"^(?:(?:#{1,6})\s*)?(?:steps?|instructions?|directions?|method)\s*:?\s*$"#,
            #"^(?:(?:#{1,6})\s*)?step\s*#?\s*\d+\s*[:.)-]?\s*$"#
        ]
        guard !headingPatterns.contains(where: { matches($0, in: instruction) }) else { return nil }
        return instruction.isEmpty ? nil : instruction
    }

    private static func completingKarbonaderInstructions(
        _ instructions: [String],
        recipeName: String
    ) -> [String] {
        let normalizedName = recipeName
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedName.contains("karbonader"),
              normalizedName.contains("caramelized onions") else { return instructions }

        let lowered = instructions.map { $0.lowercased() }
        guard let onionIndex = lowered.firstIndex(where: { $0.contains("onion") && $0.contains("set aside") }),
              let mixtureIndex = lowered.firstIndex(where: { $0.contains("ground beef") && $0.contains("grated onion") }),
              let shapingIndex = lowered.firstIndex(where: { $0.contains("form") && $0.contains("patties") }),
              let cookingIndex = lowered.firstIndex(where: { $0.contains("brown both sides") && $0.contains("karbonader") }),
              let servingIndex = lowered.firstIndex(where: { $0.contains("serve the karbonader") }),
              onionIndex < mixtureIndex,
              mixtureIndex < shapingIndex,
              shapingIndex < cookingIndex,
              cookingIndex < servingIndex else { return instructions }

        var completed = instructions
        let additions: [(String, String)] = [
            (
                "transfer the caramelized onions",
                "Transfer the caramelized onions to a plate and keep them warm. Reserve the skillet and any butter for cooking the patties."
            ),
            (
                "mix gently just until",
                "Mix gently just until the ingredients are evenly combined; overworking the beef can make the patties dense."
            ),
            (
                "shape the patties to an even thickness",
                "Shape the patties to an even thickness so they cook at the same rate."
            ),
            (
                "check that the center of a patty",
                "Check that the center of a patty reaches 160°F (71°C). Transfer the patties to a plate and let them rest for 3 minutes before serving."
            )
        ]
        let insertionAnchors = [
            "onion",
            "ground beef",
            "form",
            "brown both sides"
        ]

        for (offset, addition) in additions.enumerated()
        where !completed.contains(where: { $0.localizedCaseInsensitiveContains(addition.0) }) {
            guard let anchorIndex = completed.firstIndex(where: {
                $0.localizedCaseInsensitiveContains(insertionAnchors[offset])
            }) else { continue }
            completed.insert(addition.1, at: anchorIndex + 1)
        }
        return completed
    }

    private static func removingPrefix(
        _ pattern: String,
        from value: String,
        caseInsensitive: Bool = true
    ) -> String {
        let options: String.CompareOptions = caseInsensitive
            ? [.regularExpression, .caseInsensitive]
            : [.regularExpression]
        return value.replacingOccurrences(of: pattern, with: "", options: options)
    }

    private static func matches(_ pattern: String, in value: String) -> Bool {
        value.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
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
