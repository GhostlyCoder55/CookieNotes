//
//  AboutView.swift
//  CookieNotes
//

import SwiftUI

struct AboutView: View {
    var adsActive: Bool
    @EnvironmentObject private var tutorialManager: TutorialManager
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
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CookieNotes")
                                    .font(AppTheme.title)
                                    .foregroundStyle(AppTheme.primaryText)
                                Text("Your personal cooking library")
                                    .font(AppTheme.caption)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        }

                        aboutBlock(
                            title: "Library",
                            body: "Keep personal recipes with photos, illustrated ingredients, favorites, and cook mode."
                        )
                        aboutBlock(
                            title: "Discover",
                            body: "Search online recipes from TheMealDB, preview them, and save keepers into your journal with attribution."
                        )
                        aboutBlock(
                            title: "Privacy and ads",
                            body: "Recipes stay on this device. Ads help keep CookieNotes free."
                        )

                        HStack(spacing: AppTheme.paddingSmall) {
                            Button {
                                ads.privacySheetMode = .settings
                                ads.presentPrivacySheet = true
                            } label: {
                                Text("Ads")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryButtonStyle())

                            Button {
                                tutorialManager.resetTutorial()
                            } label: {
                                Text("Show tips")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }

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
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTheme.sectionLabel)
                .foregroundStyle(AppTheme.accent)
            Text(body)
                .font(AppTheme.body)
                .foregroundStyle(AppTheme.primaryText)
        }
        .sectionSurface()
    }
}

#Preview {
    AboutView(adsActive: false)
        .environmentObject(TutorialManager())
}
