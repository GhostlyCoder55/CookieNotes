//
//  AdvertisementSlot.swift
//  CookieNotes
//

import SwiftUI

struct AdvertisementSlot: View {
    let placementID: String
    @ObservedObject private var ads = AdMobController.shared
    @State private var failed = false

    /// Fixed banner well so tab switches and adaptive sizes cannot blow out layout.
    private let bannerWellHeight: CGFloat = 60

    var body: some View {
        if ads.canPresentAds && AdConfiguration.current.mode != .disabled && !failed {
            VStack(alignment: .leading, spacing: 8) {
                Text("ADVERTISEMENT")
                    .font(AppTheme.smallCaption.weight(.bold))
                    .foregroundStyle(AppTheme.tertiaryText)
                    .tracking(0.6)
                    .accessibilityAddTraits(.isHeader)

                GeometryReader { geometry in
                    let width = max(floor(geometry.size.width), 1)
                    AdBannerRepresentable(
                        width: width,
                        onHeight: { _ in },
                        onFailure: { failed = true }
                    )
                    .frame(width: width, height: bannerWellHeight, alignment: .center)
                    .clipped()
                }
                .frame(height: bannerWellHeight)
                .frame(maxWidth: .infinity)
                .clipped()
            }
            .padding(AppTheme.paddingMedium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.adBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                    .stroke(AppTheme.separator, lineWidth: 1)
            )
            .clipped()
            .accessibilityLabel("Advertisement")
            .accessibilityIdentifier("advertisement-slot-\(placementID)")
            .id("\(placementID)-\(ads.reloadToken)")
        }
    }
}
