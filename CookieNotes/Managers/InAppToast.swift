//
//  InAppToast.swift
//  CookieNotes
//

import Combine
import SwiftUI

/// Lightweight top-of-screen toast. Overlay only — never participates in layout.
@MainActor
final class InAppToast: ObservableObject {
    static let shared = InAppToast()

    static let recipeAddedMessage = "Recipe added to Library"
    static let displayDuration: Duration = .seconds(2)

    @Published private(set) var message: String?

    private var generation = 0

    private init() {}

    func showRecipeAdded() {
        show(Self.recipeAddedMessage)
    }

    func show(_ text: String) {
        generation += 1
        let token = generation
        message = text
        Task { @MainActor in
            try? await Task.sleep(for: Self.displayDuration)
            guard token == generation else { return }
            message = nil
        }
    }
}

/// Non-interactive toast pinned to the top of the window.
struct InAppToastOverlay: View {
    @ObservedObject private var toast = InAppToast.shared

    var body: some View {
        VStack(spacing: 0) {
            if let message = toast.message {
                HStack(spacing: AppTheme.paddingSmall) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.burntOrange)
                        .accessibilityHidden(true)
                    Text(message)
                        .font(AppTheme.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, AppTheme.paddingMedium)
                .padding(.vertical, 12)
                .background(AppTheme.bannerFill)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                .shadow(color: AppTheme.cardShadow, radius: 10, y: 4)
                .padding(.horizontal, AppTheme.paddingMedium)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityIdentifier("recipe-added-toast")
                .accessibilityAddTraits(.updatesFrequently)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.22), value: toast.message)
    }
}
