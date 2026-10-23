//
//  PendingImportStore.swift
//  CookieNotes
//

import Foundation

enum PendingImportError: Error, Equatable {
    case appGroupUnavailable
}

/// Tiny JSON inbox shared by the app and the Safari share extension.
enum PendingImportStore {
    static let appGroupID = "group.com.gc.CookieNotes"
    static let folderName = "Imports"

    static func inboxURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(folderName, isDirectory: true)
    }

    static func enqueue(_ payload: SharedRecipePayload, inbox: URL? = nil) throws {
        let folder = try resolveInbox(inbox)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let fileURL = folder.appendingPathComponent("\(UUID().uuidString).json")
        let data = try ImportCoding.encoder.encode(limited(payload))
        try data.write(to: fileURL, options: .atomic)
    }

    static func drain(inbox: URL? = nil) throws -> [SharedRecipePayload] {
        let folder = try resolveInbox(inbox)
        guard FileManager.default.fileExists(atPath: folder.path) else { return [] }

        let files = try FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }

        var payloads: [SharedRecipePayload] = []
        for file in files {
            if let data = try? Data(contentsOf: file),
               let payload = try? ImportCoding.decoder.decode(SharedRecipePayload.self, from: data) {
                payloads.append(payload)
            }
            try? FileManager.default.removeItem(at: file)
        }
        return payloads.sorted { $0.receivedAt < $1.receivedAt }
    }

    private static func resolveInbox(_ override: URL?) throws -> URL {
        if let override {
            return override
        }
        guard let url = inboxURL() else {
            throw PendingImportError.appGroupUnavailable
        }
        return url
    }

    private static func limited(_ payload: SharedRecipePayload) -> SharedRecipePayload {
        var copy = payload
        copy.title = String(copy.title.prefix(RecipeInputLimits.name))
        copy.url = String(copy.url.prefix(2_000))
        copy.text = String(copy.text.prefix(RecipeInputLimits.sharedText))
        if let image = copy.imageData, image.count > RecipeInputLimits.sharedImageBytes {
            copy.imageData = nil
        }
        return copy
    }
}

enum ImportCoding {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
