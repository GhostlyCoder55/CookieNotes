//
//  AdBannerView.swift
//  CookieNotes
//

import GoogleMobileAds
import SwiftUI
import UIKit

/// Builds a banner request. Recipe text is intentionally not sent as keywords.
enum AdRequestFactory {
    @MainActor
    static func makeRequest() -> Request {
        let request = Request()
        // Non-personalized / contextual ads only.
        let extras = Extras()
        extras.additionalParameters = ["npa": "1"]
        request.register(extras)
        return request
    }
}

struct AdBannerRepresentable: UIViewRepresentable {
    let width: CGFloat
    var onHeight: (CGFloat) -> Void
    var onFailure: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onHeight: onHeight, onFailure: onFailure)
    }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView()
        banner.adUnitID = AdConfiguration.current.bannerAdUnitID
        banner.delegate = context.coordinator
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        let usableWidth = max(floor(width), 1)
        let size = currentOrientationAnchoredAdaptiveBanner(width: usableWidth)
        guard size.size.width > 0, size.size.height > 0 else { return }

        // Avoid reload thrash when GeometryReader reports tiny width deltas across tabs.
        let widthChanged = abs(context.coordinator.lastWidth - usableWidth) >= 1
        if widthChanged || context.coordinator.needsLoad || banner.adSize.size != size.size {
            banner.adSize = size
            banner.frame = CGRect(origin: .zero, size: CGSize(width: usableWidth, height: size.size.height))
            context.coordinator.lastWidth = usableWidth
            context.coordinator.needsLoad = false
            banner.rootViewController = InterfaceLocator.topViewController()
            banner.load(AdRequestFactory.makeRequest())
        }
        onHeight(min(size.size.height, 60))
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        var needsLoad = true
        var lastWidth: CGFloat = 0
        let onHeight: (CGFloat) -> Void
        let onFailure: () -> Void

        init(onHeight: @escaping (CGFloat) -> Void, onFailure: @escaping () -> Void) {
            self.onHeight = onHeight
            self.onFailure = onFailure
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            onHeight(min(bannerView.adSize.size.height, 60))
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            onFailure()
        }
    }
}
