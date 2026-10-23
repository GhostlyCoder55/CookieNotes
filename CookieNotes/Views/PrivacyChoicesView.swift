//
//  PrivacyChoicesView.swift
//  CookieNotes
//

import SwiftUI

struct PrivacyChoicesView: View {
    @ObservedObject var ads: AdMobController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: AppTheme.paddingLarge) {
                Spacer(minLength: 12)

                FoodIconView(iconID: "honey_jar", size: 72)

                Text(ads.privacySheetMode == .firstRun ? "Keep CookieNotes free" : "Ads")
                    .font(AppTheme.title)
                    .foregroundStyle(AppTheme.primaryText)
                    .multilineTextAlignment(.center)

                Text("Ads help support the app. Your recipes stay on this device.")
                    .font(AppTheme.body)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, AppTheme.paddingSmall)

                if ads.privacySheetMode == .settings {
                    Text("Current choice: \(AdConsentStore.choice().title)")
                        .font(AppTheme.caption)
                        .foregroundStyle(AppTheme.tertiaryText)
                }

                VStack(spacing: AppTheme.paddingSmall) {
                    choiceButton("Show ads", choice: .allowed, emphasis: true)
                    choiceButton("Don’t show ads", choice: .declined, emphasis: false)
                }
                .padding(.top, AppTheme.paddingSmall)

                if ads.privacySheetMode == .settings {
                    Button("Done") { dismiss() }
                        .font(AppTheme.body.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(minHeight: 44)
                }

                Spacer(minLength: 12)
            }
            .padding(AppTheme.paddingLarge)
            .frame(maxWidth: 400)
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(ads.privacySheetMode == .firstRun)
    }

    private func choiceButton(_ title: String, choice: AdConsentChoice, emphasis: Bool) -> some View {
        Button {
            ads.stageChoice(choice)
            dismiss()
        } label: {
            Text(title)
                .font(AppTheme.headline)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, AppTheme.paddingMedium)
                .background(emphasis ? AppTheme.burntOrange : AppTheme.surfaceBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint(choice == AdConsentStore.choice() ? "Current choice" : "Updates your ad choice")
    }
}
