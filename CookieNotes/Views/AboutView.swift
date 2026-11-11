//
//  AboutView.swift
//  CookieNotes
//

import SwiftUI

struct AboutView: View {
    var adsActive: Bool
    @ObservedObject private var ads = AdMobController.shared
    @ObservedObject private var languageManager = AppLanguageManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.paddingLarge) {
                    HStack(spacing: 14) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .accessibilityHidden(true)
                        TitleSubtitleBlock(
                            title: "CookieNotes",
                            subtitle: String.localized("Your personal cooking library"),
                            style: .compact,
                            alignment: .leading
                        )
                    }

                    // Language Section
                    VStack(alignment: .leading, spacing: AppTheme.paddingMedium) {
                        Text(String.localized("Language"))
                            .font(AppTheme.sectionLabel)
                            .foregroundStyle(AppTheme.accent)
                            .accessibilityAddTraits(.isHeader)

                        VStack(spacing: 4) {
                            ForEach(AppLanguage.allCases) { lang in
                                let isSelected = languageManager.currentLanguage == lang
                                Button {
                                    languageManager.setLanguage(lang)
                                } label: {
                                    HStack(spacing: 12) {
                                        radioDot(isSelected: isSelected)

                                        Text(lang.flag)
                                            .font(.title3)

                                        Text(lang.displayName)
                                            .font(AppTheme.headline)
                                            .foregroundStyle(AppTheme.primaryText)

                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(minHeight: 44)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(lang.titleWithFlag)
                                .accessibilityAddTraits(isSelected ? .isSelected : [])

                                if lang != AppLanguage.allCases.last {
                                    Divider()
                                        .overlay(AppTheme.separator)
                                }
                            }
                        }
                    }
                    .sectionSurface()
                    .sensoryFeedback(.selection, trigger: languageManager.currentLanguage)

                    VStack(alignment: .leading, spacing: AppTheme.paddingMedium) {
                        aboutBlock(
                            title: String.localized("Library"),
                            body: String.localized("Keep personal recipes with photos, illustrated ingredients, favorites, and cook mode.")
                        )
                        aboutBlock(
                            title: String.localized("Discover"),
                            body: String.localized("Explore recipes from the database, preview the details, and save your favorites directly to your journal.")
                        )
                        aboutBlock(
                            title: String.localized("List"),
                            body: String.localized("Keep a grocery checklist, check items off as you shop, sort, and clear completed items anytime.")
                        )
                        aboutBlock(
                            title: String.localized("Privacy and ads"),
                            body: String.localized("Recipes stay on this device. Ads help keep CookieNotes free.")
                        )

                        Button {
                            ads.privacySheetMode = .settings
                            ads.presentPrivacySheet = true
                        } label: {
                            Text(String.localized("Ads"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .sectionSurface()

                    if adsActive && ads.canPresentAds {
                        AdvertisementSlot(placementID: "about")
                    }
                }
                .padding(AppTheme.paddingMedium)
            }
            .softTopScrollEdgeEffect()
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(String.localized("About"))
            .navigationBarTitleDisplayMode(.large)
        }
        .preferredColorScheme(.dark)
    }

    private func radioDot(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? AppTheme.burntOrange : AppTheme.separator, lineWidth: 2)
                .frame(width: 22, height: 22)

            if isSelected {
                Circle()
                    .fill(AppTheme.burntOrange)
                    .frame(width: 12, height: 12)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: isSelected)
    }

    private func aboutBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.paddingSmall) {
            Text(title)
                .font(AppTheme.sectionLabel)
                .foregroundStyle(AppTheme.accent)
                .accessibilityAddTraits(.isHeader)
            Text(body)
                .font(AppTheme.body)
                .foregroundStyle(AppTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    AboutView(adsActive: false)
}
