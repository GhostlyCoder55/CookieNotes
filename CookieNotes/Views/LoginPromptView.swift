//
//  LoginPromptView.swift
//  CookieNotes
//

import SwiftUI

struct WelcomeBackPromptView: View {
    @ObservedObject var notificationManager: NotificationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: AppTheme.paddingLarge) {
            FoodIconView(iconID: "cupcake", size: 80)
                .scaleEffect(!reduceMotion && isAnimating ? 1.05 : 1)
                .animation(reduceMotion ? nil : .easeInOut(duration: 1).repeatForever(autoreverses: true), value: isAnimating)

            TitleSubtitleBlock(
                title: "Welcome Back",
                subtitle: "Your recipes are waiting. Add something new, discover online, or open a favorite.",
                style: .page,
                alignment: .center
            )

            if let lastLogin = notificationManager.lastLoginDate {
                Text("Last visit: \(lastLogin, style: .date)")
                    .font(AppTheme.caption)
                    .foregroundStyle(AppTheme.tertiaryText)
            }

            Button {
                notificationManager.markUserAsActive()
            } label: {
                Label("Start Cooking", systemImage: "fork.knife")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())

            Button("Maybe Later") {
                notificationManager.dismissPrompt()
            }
            .foregroundStyle(AppTheme.secondaryText)
            .frame(minHeight: 44)
        }
        .padding(AppTheme.paddingLarge)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        .shadow(color: AppTheme.cardShadow, radius: 12, y: 6)
        .onAppear {
            if !reduceMotion { isAnimating = true }
        }
    }
}

typealias LoginPromptView = WelcomeBackPromptView

struct LoginPromptOverlay: View {
    @ObservedObject private var notificationManager = NotificationManager.shared

    var body: some View {
        if notificationManager.shouldShowLoginPrompt {
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { notificationManager.dismissPrompt() }
                WelcomeBackPromptView(notificationManager: notificationManager)
                    .padding()
            }
        }
    }
}
