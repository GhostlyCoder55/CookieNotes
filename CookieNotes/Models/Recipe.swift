//
//  Recipe.swift
//  CookieNotes
//
//  Created by Christopher Ogbonnaya on 2025-10-26.
//

import Foundation

struct Recipe: Identifiable, Codable, Hashable, Equatable {
    let id = UUID()
    var name: String
    var ingredients: [String]
    var instructions: [String]
    var prepTime: Int // in minutes
    var cookTime: Int // in minutes
    var dateCreated: Date
    var dateModified: Date
    
    init(name: String, ingredients: [String] = [], instructions: [String] = [], prepTime: Int = 0, cookTime: Int = 0) {
        self.name = name
        self.ingredients = ingredients
        self.instructions = instructions
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.dateCreated = Date()
        self.dateModified = Date()
    }
    
    var totalTime: Int {
        prepTime + cookTime
    }
    
    var formattedPrepTime: String {
        if prepTime == 0 { return "No prep" }
        return "\(prepTime) min prep"
    }
    
    var formattedCookTime: String {
        if cookTime == 0 { return "No cook" }
        return "\(cookTime) min cook"
    }
    
    var formattedTotalTime: String {
        if totalTime == 0 { return "Instant" }
        return "\(totalTime) min total"
    }
}
