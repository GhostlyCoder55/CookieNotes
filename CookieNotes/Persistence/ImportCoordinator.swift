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

    func consumePendingImports(context: ModelContext) {
        let payloads: [SharedRecipePayload]
        do {
            payloads = try PendingImportStore.drain()
        } catch PendingImportError.appGroupUnavailable {
            return
        } catch {
            AppLog.storage.error("Shared recipe inbox could not be read")
            return
        }

        guard !payloads.isEmpty else { return }

        var savedNames: [String] = []
        for payload in payloads {
            let draft = SharedRecipeBuilder.draft(from: payload)
            guard !draft.name.isEmpty else { continue }

            let recipe = Recipe(
                name: draft.name,
                ingredients: draft.ingredients,
                instructions: draft.instructions,
                notes: draft.notes,
                source: draft.source,
                servings: draft.servings,
                isImported: true
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
            bannerMessage = "A shared recipe couldn't be saved."
            AppLog.storage.error("Shared recipe save failed")
            return
        }

        if !savedNames.isEmpty {
            InAppToast.shared.showRecipeAdded()
        }
    }
}
