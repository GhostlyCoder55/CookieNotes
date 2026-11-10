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

                TitleSubtitleBlock(
                    title: ads.privacySheetMode == .firstRun ? String.localized("Keep CookieNotes free") : String.localized("Ads"),
                    subtitle: String.localized("Ads help support the app. Your recipes stay on this device."),
                    style: .page,
                    alignment: .center
                )
                .padding(.horizontal, AppTheme.paddingSmall)

                if ads.privacySheetMode == .settings {
                    Text(String.localized("Current choice: %@", AdConsentStore.choice().title))
                        .font(AppTheme.caption)
                        .foregroundStyle(AppTheme.tertiaryText)
                }

                VStack(spacing: AppTheme.paddingSmall) {
                    choiceButton(String.localized("Show ads"), choice: .allowed, emphasis: true)
                    choiceButton(String.localized("Don’t show ads"), choice: .declined, emphasis: false)
                }
                .padding(.top, AppTheme.paddingSmall)

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
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(ChoiceButtonStyle(emphasis: emphasis))
        .accessibilityHint(choice == AdConsentStore.choice() ? String.localized("Current choice") : String.localized("Updates your ad choice"))
    }
}

private struct ChoiceButtonStyle: ButtonStyle {
    let emphasis: Bool

    func makeBody(configuration: Configuration) -> some View {
        BodyView(emphasis: emphasis, configuration: configuration)
    }

    private struct BodyView: View {
        let emphasis: Bool
        let configuration: Configuration
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .font(AppTheme.headline)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, AppTheme.paddingMedium)
                .background(emphasis ? AppTheme.burntOrange : AppTheme.surfaceBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                .opacity(configuration.isPressed ? 0.9 : 1)
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
}
