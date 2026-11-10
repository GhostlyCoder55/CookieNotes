//
//  ImportCoordinator.swift
//  CookieNotes
//

import Foundation
import SwiftData

@MainActor
final class ImportCoordinator: ObservableObject {
    static let shared = ImportCoordinator()

    @Published var bannerMessage: String?

    func consumePendingImports(context: ModelContext, inbox: URL? = nil) {
        let payloads: [SharedRecipePayload]
        do {
            payloads = try PendingImportStore.drain(inbox: inbox)
        } catch PendingImportError.appGroupUnavailable {
            return
        } catch {
            AppLog.storage.error("Shared recipe inbox could not be read")
            return
        }

        guard !payloads.isEmpty else { return }

        let existingImported = (try? context.fetch(
            FetchDescriptor<Recipe>(predicate: #Predicate { $0.isSample == false && $0.isImported == true })
        )) ?? []
        var knownSourceURLs = Set(
            existingImported
                .compactMap { RecipeSanitizer.webURL($0.source)?.lowercased() }
        )

        var savedNames: [String] = []
        for payload in payloads {
            let draft = SharedRecipeBuilder.draft(from: payload)
            guard !draft.name.isEmpty else { continue }

            if let normalizedURL = RecipeSanitizer.webURL(draft.source)?.lowercased() {
                guard knownSourceURLs.insert(normalizedURL).inserted else { continue }
            }

            let iconIDs = draft.ingredients.map { IngredientCatalog.iconID(matching: $0) ?? "" }
            let recipe = Recipe(
                name: draft.name,
                ingredients: draft.ingredients,
                instructions: draft.instructions,
                notes: draft.notes,
                source: draft.source,
                servings: draft.servings,
                isImported: true,
                ingredientIconIDs: iconIDs
            )
            context.insert(recipe)

            if let imageData = payload.imageData,
               imageData.count <= RecipeInputLimits.sharedImageBytes,
               let stored = PhotoProcessing.makeStoredPhoto(from: imageData) {
                let photo = RecipePhoto(sortIndex: 0, imageData: stored.imageData, thumbnailData: stored.thumbnailData)
                photo.recipe = recipe
                context.insert(photo)
            }
            savedNames.append(recipe.name)
        }

        do {
            if !savedNames.isEmpty {
                try context.save()
            }
        } catch {
            bannerMessage = String.localized("A shared recipe couldn't be saved.")
            AppLog.storage.error("Shared recipe save failed")
            return
        }

        if !savedNames.isEmpty {
            InAppToast.shared.showRecipeAdded()
        }
    }
}
