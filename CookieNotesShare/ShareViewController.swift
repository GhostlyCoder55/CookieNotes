//
//  ShareViewController.swift
//  CookieNotesShare
//

import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let saveButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private var payload: SharedRecipePayload?

    private enum Palette {
        static let background = UIColor(red: 0.06, green: 0.055, blue: 0.05, alpha: 1)
        static let accent = UIColor(red: 0.60, green: 0.40, blue: 0.20, alpha: 1)
        static let primaryText = UIColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1)
        static let secondaryText = UIColor(red: 0.84, green: 0.81, blue: 0.76, alpha: 1)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.background
        configureLayout()
        Task { await loadShare() }
    }

    private func configureLayout() {
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = Palette.primaryText
        titleLabel.numberOfLines = 2
        titleLabel.text = "Save to CookieNotes"

        detailLabel.font = .preferredFont(forTextStyle: .body)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textColor = Palette.secondaryText
        detailLabel.numberOfLines = 0
        detailLabel.text = "Reading…"

        var saveConfig = UIButton.Configuration.filled()
        saveConfig.title = "Save recipe"
        saveConfig.baseBackgroundColor = Palette.accent
        saveConfig.baseForegroundColor = Palette.primaryText
        saveConfig.cornerStyle = .medium
        saveConfig.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        saveButton.configuration = saveConfig
        saveButton.isEnabled = false
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        cancelButton.titleLabel?.adjustsFontForContentSizeCategory = true
        cancelButton.setTitleColor(Palette.secondaryText, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let stack = UIStackView(arrangedSubviews: [titleLabel, detailLabel, saveButton, cancelButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24)
        ])
    }

    private func loadShare() async {
        let loaded = await Self.readPayload(from: extensionContext)
        payload = loaded
        if let loaded {
            let draft = SharedRecipeBuilder.draft(from: loaded)
            titleLabel.text = draft.name
            if draft.ingredients.isEmpty && draft.instructions.isEmpty {
                detailLabel.text = "You can add ingredients and steps after it opens in CookieNotes."
            } else {
                detailLabel.text = "\(draft.ingredients.count) ingredients · \(draft.instructions.count) steps"
            }
            saveButton.isEnabled = true
        } else {
            titleLabel.text = "Nothing to save"
            detailLabel.text = "Share a link, some text, or a photo of a dish."
            saveButton.isEnabled = false
        }
    }

    @objc private func saveTapped() {
        guard let payload else { return }
        do {
            try PendingImportStore.enqueue(payload)
            extensionContext?.completeRequest(returningItems: nil)
        } catch PendingImportError.appGroupUnavailable {
            detailLabel.text = "Turn on the CookieNotes App Group in Xcode, then try again."
        } catch {
            detailLabel.text = "CookieNotes couldn't save this. Try again."
        }
    }

    @objc private func cancelTapped() {
        let error = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
        extensionContext?.cancelRequest(withError: error)
    }

    private static func readPayload(from context: NSExtensionContext?) async -> SharedRecipePayload? {
        guard let items = context?.inputItems as? [NSExtensionItem] else { return nil }
        var title = ""
        var url = ""
        var text = ""
        var imageData: Data?

        for item in items {
            if title.isEmpty {
                title = item.attributedTitle?.string ?? item.attributedContentText?.string ?? ""
            }
            for provider in item.attachments ?? [] {
                if url.isEmpty, provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    url = await loadURL(from: provider) ?? ""
                }
                if text.isEmpty, provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    text = await loadText(from: provider) ?? ""
                }
                if imageData == nil, provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    imageData = await loadImage(from: provider)
                }
            }
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && url.isEmpty && trimmedText.isEmpty && imageData == nil {
            return nil
        }
        return SharedRecipePayload(title: title, url: url, text: text, imageData: imageData, receivedAt: Date())
    }

    private static func loadURL(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                let value: String?
                if let url = item as? URL {
                    value = url.absoluteString
                } else if let url = item as? NSURL {
                    value = url.absoluteString
                } else {
                    value = nil
                }
                continuation.resume(returning: value)
            }
        }
    }

    private static func loadText(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                continuation.resume(returning: item as? String)
            }
        }
    }

    private static func loadImage(from provider: NSItemProvider) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, _ in
                let data: Data?
                if let image = item as? UIImage {
                    data = image.jpegData(compressionQuality: 0.9)
                } else if let raw = item as? Data {
                    data = raw
                } else if let url = item as? URL {
                    data = try? Data(contentsOf: url)
                } else {
                    data = nil
                }
                if let data, let stored = PhotoProcessing.makeStoredPhoto(from: data) {
                    continuation.resume(returning: stored.imageData)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
