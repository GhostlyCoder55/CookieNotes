//
//  AboutView.swift
//  CookieNotes
//

import SwiftUI

struct AboutView: View {
    var adsActive: Bool
    @ObservedObject private var ads = AdMobController.shared

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.paddingLarge) {
                        HStack(spacing: 14) {
                            Image("AppLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            TitleSubtitleBlock(
                                title: "CookieNotes",
                                subtitle: "Your personal cooking library",
                                style: .compact,
                                alignment: .leading
                            )
                        }

                        VStack(alignment: .leading, spacing: AppTheme.paddingMedium) {
                            aboutBlock(
                                title: "Library",
                                body: "Keep personal recipes with photos, illustrated ingredients, favorites, and cook mode."
                            )
                            aboutBlock(
                                title: "Discover",
                                body: "Explore recipes from the database, preview the details, and save your favorites directly to your journal."
                            )
                            aboutBlock(
                                title: "Privacy and ads",
                                body: "Recipes stay on this device. Ads help keep CookieNotes free."
                            )

                            Button {
                                ads.privacySheetMode = .settings
                                ads.presentPrivacySheet = true
                            } label: {
                                Text("Ads")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                        .sectionSurface()

                        if adsActive && ads.canPresentAds {
                            AdvertisementSlot(placementID: "about")
                        }

                        Text("Created by Christopher Ogbonnaya")
                            .font(AppTheme.caption)
                            .foregroundStyle(AppTheme.tertiaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, AppTheme.paddingXLarge)
                    }
                    .padding(AppTheme.paddingMedium)
                }
            }
            .navigationTitle("About")
        }
        .preferredColorScheme(.dark)
    }

    private func aboutBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.paddingSmall) {
            Text(title)
                .font(AppTheme.sectionLabel)
                .foregroundStyle(AppTheme.accent)
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
