//
//  RecipeTimeEstimator.swift
//  CookieNotes
//
//  TheMealDB has no prep/cook fields, so Discover derives them from the steps.
//

import Foundation

struct RecipeTimeEstimate: Hashable {
    let prep: Int
    let cook: Int

    var total: Int { prep + cook }
}

enum RecipeTimeEstimator {
    static func estimate(instructions: [String], ingredientCount: Int, category: String?) -> RecipeTimeEstimate {
        var passive = 0
        var cook = 0
        var mentionsHeat = false
        let allSentences = sentences(in: instructions)

        for sentence in allSentences {
            let lowered = sentence.lowercased()
            var minutes = durations(in: lowered).reduce(0, +)
            // "Cook the pasta according to the packet instructions" — typical boil time.
            if minutes == 0,
               (lowered.contains("according to") && (lowered.contains("pack") || lowered.contains("instruction") || lowered.contains("directions")))
                || (lowered.contains("selon") && (lowered.contains("emballage") || lowered.contains("paquet") || lowered.contains("instructions"))) {
                minutes = 10
            }
            let words = lowered.split { !$0.isLetter }.map(String.init)
            let isPassive = words.contains(where: passiveWords.contains) && !lowered.contains("rest of") && !lowered.contains("reste de") && !lowered.contains("reste du") && !lowered.contains("reste des")
            if words.contains(where: { word in heatPrefixes.contains { word.hasPrefix($0) } }) {
                mentionsHeat = true
            }
            if lowered.contains("overnight") || lowered.contains("toute la nuit") || lowered.contains("jusqu'au lendemain") {
                passive += 8 * 60
            }
            guard minutes > 0 else { continue }
            if isPassive {
                passive += minutes
            } else {
                cook += minutes
            }
        }

        // Too little text to tell (e.g. "Make and enjoy") — assume a typical dish of its kind.
        if cook == 0, mentionsHeat || allSentences.count < 3 {
            cook = fallbackCookMinutes(for: category)
        }
        cook = min(roundToFive(cook), 12 * 60)

        let stepCount = max(instructions.count, 1)
        let active = Double(5) + Double(ingredientCount) * 1.5 + Double(min(stepCount, 12))
        let prep = min(max(roundToFive(Int(active.rounded())), 5), 45) + min(roundToFive(passive), 24 * 60)

        return RecipeTimeEstimate(prep: prep, cook: cook)
    }

    // MARK: - Parsing

    /// Whole words only — "chill" must not match "chilli", nor "proof" match "ovenproof".
    private static let passiveWords: Set<String> = [
        "marinate", "marinated", "marinating", "marinade", "mariner",
        "chill", "chilled", "chilling", "refroidir", "refroidissez", "tiédir",
        "refrigerate", "refrigerated", "refrigerator", "fridge", "réfrigérer", "réfrigérez", "frigo", "réfrigérateur",
        "freeze", "freezer", "congeler", "congelez", "congélateur",
        "rest", "resting", "repos", "reposer", "reposez",
        "soak", "soaking", "tremper", "trempez", "macérer",
        "stand", "standing", "cool", "cooling",
        "prove", "proving", "rise", "lever", "pousser",
        "steep", "steeping", "infuser", "infusez", "overnight"
    ]

    private static let heatPrefixes = [
        "bak", "boil", "simmer", "fry", "fried", "roast", "grill", "cook", "saut",
        "sear", "brown", "oven", "heat", "steam", "poach", "broil", "toast", "stew",
        "cuir", "cuis", "bouill", "mijot", "frir", "rôt", "gril", "sais", "dor", "four", "chauff", "vapeur", "poch", "brais"
    ]

    private static let numberWords: [String: Double] = [
        "a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6,
        "seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12,
        "fifteen": 15, "twenty": 20, "thirty": 30, "forty": 40, "forty-five": 45,
        "sixty": 60, "few": 3, "a few": 3, "couple of": 2, "a couple of": 2, "several": 4,
        "half an": 0.5, "half a": 0.5,
        "un": 1, "une": 1, "deux": 2, "trois": 3, "quatre": 4, "cinq": 5,
        "sept": 7, "huit": 8, "neuf": 9, "dix": 10, "onze": 11, "douze": 12,
        "quinze": 15, "vingt": 20, "trente": 30, "quarante": 40, "quarante-cinq": 45,
        "soixante": 60, "quelques": 3, "plusieurs": 4, "demi": 0.5, "une demi": 0.5
    ]

    private static let durationRegex: NSRegularExpression = {
        let words = numberWords.keys.sorted { $0.count > $1.count }
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")
        let number = "(\\d+(?:[.,]\\d+)?|\(words))"
        let pattern = "(?<![\\w-])\(number)(?:\\s*(?:-|–|to|or|à|et)\\s*\(number))?\\s*(?:more\\s+|extra\\s+|further\\s+|de\\s+plus\\s+|environ\\s+)?(hours?|heures?|hrs?|h|minutes?|mins?)\\b"
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    private static func durations(in sentence: String) -> [Int] {
        let range = NSRange(sentence.startIndex..., in: sentence)
        return durationRegex.matches(in: sentence, range: range).compactMap { match in
            guard let unitRange = Range(match.range(at: 3), in: sentence),
                  let lowRange = Range(match.range(at: 1), in: sentence) else { return nil }
            let high = Range(match.range(at: 2), in: sentence).flatMap { value(of: String(sentence[$0])) }
            guard let amount = high ?? value(of: String(sentence[lowRange])) else { return nil }
            let unit = sentence[unitRange]
            let minutes = unit.hasPrefix("h") ? amount * 60 : amount
            guard minutes > 0, minutes <= 24 * 60 else { return nil }
            return Int(minutes.rounded())
        }
    }

    private static func value(of token: String) -> Double? {
        let cleaned = token.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return Double(cleaned) ?? numberWords[cleaned]
    }

    private static func sentences(in instructions: [String]) -> [String] {
        instructions
            .flatMap { $0.components(separatedBy: CharacterSet(charactersIn: ".!?;\n")) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func fallbackCookMinutes(for category: String?) -> Int {
        switch category?.lowercased() {
        case "beef", "lamb", "goat": 60
        case "pork": 45
        case "chicken": 40
        case "seafood", "pasta": 20
        case "breakfast": 15
        case "dessert", "vegetarian", "vegan": 30
        default: 30
        }
    }

    private static func roundToFive(_ minutes: Int) -> Int {
        guard minutes > 0 else { return 0 }
        return max(5, Int((Double(minutes) / 5).rounded()) * 5)
    }
}

enum RecipeTimeFormat {
    /// "45 min", "1 hr", "2 hr 15 min".
    static func short(_ minutes: Int) -> String {
        guard minutes > 0 else { return String.localized("0 min") }
        let hours = minutes / 60
        let rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return String.localized("%lld min", rest)
        case (_, 0): return String.localized("%lld hr", hours)
        default: return String.localized("%lld hr %lld min", hours, rest)
        }
    }
}
