//
//  TrackingExplainerView.swift
//  CookieNotes
//

import SwiftUI

/// On-brand overlay matching CookieNotes cards (dark surface, burnt orange actions).
struct TrackingExplainerView: View {
    var onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: AppTheme.paddingLarge) {
                FoodIconView(iconID: "honey_jar", size: 72)

                Text("Keep CookieNotes free")
                    .font(AppTheme.title)
                    .foregroundStyle(AppTheme.primaryText)
                    .multilineTextAlignment(.center)

                Text("Ads help support the app. Your recipes stay on this device.")
                    .font(AppTheme.body)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)

                Button("Continue", action: onContinue)
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: .infinity)
            }
            .padding(AppTheme.paddingLarge)
            .frame(maxWidth: 360)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
            .shadow(color: AppTheme.cardShadow, radius: 16, y: 8)
            .padding()
        }
        .preferredColorScheme(.dark)
    }
}
