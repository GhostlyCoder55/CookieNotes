//
//  AdvertisementSlot.swift
//  CookieNotes
//

import SwiftUI

struct AdvertisementSlot: View {
    let placementID: String
    @ObservedObject private var ads = AdMobController.shared
    @State private var failed = false
    @State private var height: CGFloat = 60

    var body: some View {
        if ads.canPresentAds && AdConfiguration.current.mode != .disabled && !failed {
            VStack(alignment: .leading, spacing: 8) {
                Text("ADVERTISEMENT")
                    .font(AppTheme.smallCaption.weight(.bold))
                    .foregroundStyle(AppTheme.tertiaryText)
                    .tracking(0.6)
                    .accessibilityAddTraits(.isHeader)

                GeometryReader { geometry in
                    AdBannerRepresentable(
                        width: geometry.size.width,
                        onHeight: { if $0 > 1 { height = $0 } },
                        onFailure: { failed = true }
                    )
                }
                .frame(height: max(height, 50))
            }
            .padding(AppTheme.paddingMedium)
            .background(AppTheme.adBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                    .stroke(AppTheme.separator, lineWidth: 1)
            )
            .accessibilityLabel("Advertisement")
            .accessibilityIdentifier("advertisement-slot-\(placementID)")
            .id("\(placementID)-\(ads.reloadToken)")
        }
    }
}
