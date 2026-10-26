//
//  InAppToast.swift
//  CookieNotes
//

import Combine
import SwiftUI

/// Lightweight toast. Overlay only — never participates in layout.
@MainActor
final class InAppToast: ObservableObject {
    static let shared = InAppToast()

    static let recipeAddedMessage = "Recipe added to Library"
    static let displayDuration: Duration = .seconds(2)

    @Published private(set) var message: String?
    @Published private(set) var isVisible = false

    private var generation = 0

    private init() {}

    func showRecipeAdded() {
        show(Self.recipeAddedMessage)
    }

    func show(_ text: String) {
        generation += 1
        let token = generation
        message = text
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: Self.displayDuration)
            guard token == generation else { return }
            withAnimation(.easeIn(duration: 0.18)) {
                isVisible = false
            }
            try? await Task.sleep(for: .milliseconds(200))
            guard token == generation else { return }
            message = nil
        }
    }
}

/// Place this as `.overlay(alignment: .top)` on content **inside** a `NavigationStack`
/// that uses `.searchable`. That puts the toast directly under the search bar
/// without overlapping the status bar or shifting layout.
struct InAppToastOverlay: View {
    @ObservedObject private var toast = InAppToast.shared

    var body: some View {
        Group {
            if let message = toast.message {
                toastCard(message)
                    .padding(.horizontal, AppTheme.paddingMedium)
                    .padding(.top, 8)
                    .opacity(toast.isVisible ? 1 : 0)
                    .scaleEffect(toast.isVisible ? 1 : 0.98)
                    .accessibilityIdentifier("recipe-added-toast")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }

    private func toastCard(_ message: String) -> some View {
        HStack(spacing: AppTheme.paddingSmall) {
            Image(systemName: "checkmark.circle.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.burntOrange)
                .accessibilityHidden(true)
            Text(message)
                .font(AppTheme.caption.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, AppTheme.paddingMedium)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .fill(AppTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .stroke(AppTheme.burntOrange.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 12, y: 6)
    }
}
