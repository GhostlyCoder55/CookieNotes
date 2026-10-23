//
//  AppTheme.swift
//  CookieNotes
//

import SwiftUI
import UIKit

struct AppTheme {
    // MARK: Official CookieNotes palette (accents stay warm in both themes)
    /// Warm, distinctive primary accent.
    static let burntOrange = Color(red: 198 / 255, green: 93 / 255, blue: 36 / 255)   // #C65D24
    /// Highlights, interactive elements, and food illustrations.
    static let brightOrange = Color(red: 240 / 255, green: 138 / 255, blue: 67 / 255) // #F08A43
    /// Cheerful warm accent for recipe categories.
    static let goldenYellow = Color(red: 251 / 255, green: 227 / 255, blue: 98 / 255) // #FBE362
    /// Earthy cooking-journal character.
    static let warmBrown = Color(red: 107 / 255, green: 82 / 255, blue: 33 / 255)     // #6B5221
    /// Near-black for type and contrast (light theme).
    static let nearBlack = Color(red: 18 / 255, green: 16 / 255, blue: 15 / 255)      // #12100F

    // Illustration helpers (keep food art lively)
    static let leafGreen = Color(red: 0.42, green: 0.68, blue: 0.32)
    static let tomatoRed = Color(red: 0.86, green: 0.28, blue: 0.22)
    static let berryBlue = Color(red: 0.35, green: 0.55, blue: 0.88)
    static let creamWhite = Color(red: 1.0, green: 0.98, blue: 0.94)

    // MARK: Adaptive surfaces — cream journal by day, warm charcoal by night
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    private static let lightCream = UIColor(red: 1.0, green: 0.97, blue: 0.92, alpha: 1)
    private static let lightParchment = UIColor(red: 0.99, green: 0.94, blue: 0.86, alpha: 1)
    private static let darkBase = UIColor(red: 0.09, green: 0.08, blue: 0.07, alpha: 1)       // #171412
    private static let darkElevated = UIColor(red: 0.16, green: 0.14, blue: 0.12, alpha: 1)  // #29231F
    private static let darkCard = UIColor(red: 0.20, green: 0.17, blue: 0.14, alpha: 1)      // #332B24
    private static let darkCreamText = UIColor(red: 0.97, green: 0.94, blue: 0.88, alpha: 1) // #F7F0E0
    private static let darkSecondary = UIColor(red: 0.78, green: 0.66, blue: 0.48, alpha: 1) // #C7A87A

    static let cream = adaptive(light: lightCream, dark: darkBase)
    static let parchment = adaptive(light: lightParchment, dark: darkElevated)
    static let background = cream
    static let backgroundSecondary = parchment
    static let cardBackground = adaptive(light: .white, dark: darkCard)
    static let surfaceBackground = parchment
    static let primaryText = adaptive(
        light: UIColor(red: 18 / 255, green: 16 / 255, blue: 15 / 255, alpha: 1),
        dark: darkCreamText
    )
    static let secondaryText = adaptive(
        light: UIColor(red: 107 / 255, green: 82 / 255, blue: 33 / 255, alpha: 0.85),
        dark: darkSecondary
    )
    static let tertiaryText = adaptive(
        light: UIColor(red: 107 / 255, green: 82 / 255, blue: 33 / 255, alpha: 0.55),
        dark: UIColor(red: 0.78, green: 0.66, blue: 0.48, alpha: 0.65)
    )
    static let separator = adaptive(
        light: UIColor(red: 107 / 255, green: 82 / 255, blue: 33 / 255, alpha: 0.18),
        dark: UIColor(red: 0.78, green: 0.66, blue: 0.48, alpha: 0.22)
    )
    static let accent = burntOrange
    static let accentWarm = goldenYellow
    static let accentAction = brightOrange
    static let adBackground = parchment
    static let error = Color(red: 0.78, green: 0.22, blue: 0.18)
    static let success = leafGreen
    static let bannerFill = adaptive(
        light: UIColor(red: 251 / 255, green: 227 / 255, blue: 98 / 255, alpha: 0.35),
        dark: UIColor(red: 198 / 255, green: 93 / 255, blue: 36 / 255, alpha: 0.28)
    )
    static let elevatedHighlight = adaptive(light: .white, dark: darkElevated)

    // Compatibility aliases used across views
    static let cocoa = warmBrown
    static let mustard = goldenYellow
    static let coral = brightOrange
    static let strawberry = burntOrange
    static let leaf = leafGreen
    static let sky = brightOrange
    static let grape = warmBrown
    static let blush = parchment
    static let ink = primaryText
    static let primaryBlack = primaryText
    static let secondaryBrown = burntOrange
    static let accentBrown = warmBrown
    static let lightBrown = brightOrange.opacity(0.55)
    static let accentYellow = goldenYellow
    static let cardShadow = adaptive(
        light: UIColor(white: 0, alpha: 0.08),
        dark: UIColor(white: 0, alpha: 0.45)
    )
    static let buttonShadow = adaptive(
        light: UIColor(white: 0, alpha: 0.06),
        dark: UIColor(white: 0, alpha: 0.35)
    )

    // Typography
    static let largeTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let title = Font.system(.title2, design: .rounded).weight(.bold)
    static let headline = Font.system(.headline, design: .rounded).weight(.semibold)
    static let body = Font.system(.body, design: .rounded)
    static let caption = Font.system(.subheadline, design: .rounded)
    static let smallCaption = Font.system(.caption, design: .rounded)
    static let sectionLabel = Font.system(.subheadline, design: .rounded).weight(.bold)

    // Spacing / radii
    static let paddingTiny: CGFloat = 4
    static let paddingSmall: CGFloat = 8
    static let paddingMedium: CGFloat = 16
    static let paddingLarge: CGFloat = 24
    static let paddingXLarge: CGFloat = 32
    static let cornerRadiusSmall: CGFloat = 12
    static let cornerRadiusMedium: CGFloat = 18
    static let cornerRadiusLarge: CGFloat = 24
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.headline)
            .foregroundStyle(Color.white)
            .padding(.horizontal, AppTheme.paddingMedium)
            .padding(.vertical, 12)
            .frame(minHeight: 48)
            .background(
                (configuration.isPressed ? AppTheme.brightOrange : AppTheme.burntOrange)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.headline)
            .foregroundStyle(configuration.isPressed ? AppTheme.brightOrange : AppTheme.burntOrange)
            .padding(.horizontal, AppTheme.paddingMedium)
            .padding(.vertical, 12)
            .frame(minHeight: 48)
            .background(configuration.isPressed ? AppTheme.goldenYellow.opacity(0.45) : AppTheme.parchment)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                    .stroke(AppTheme.burntOrange.opacity(configuration.isPressed ? 0.55 : 0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct CardStyle: ViewModifier {
    var tint: Color = .clear

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                    .fill(AppTheme.cardBackground)
                    .shadow(color: AppTheme.cardShadow, radius: 10, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                    .stroke(tint.opacity(tint == .clear ? 0 : 0.4), lineWidth: 2)
            )
    }
}

struct SectionSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppTheme.paddingMedium)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            .shadow(color: AppTheme.cardShadow, radius: 8, y: 3)
    }
}

extension View {
    func cardStyle(tint: Color = .clear) -> some View {
        modifier(CardStyle(tint: tint))
    }

    func sectionSurface() -> some View {
        modifier(SectionSurface())
    }
}

struct EditableLine: Identifiable, Equatable {
    let id: UUID
    var text: String
    var iconID: String

    init(id: UUID = UUID(), text: String, iconID: String = "") {
        self.id = id
        self.text = text
        self.iconID = iconID
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(AppTheme.body)
            .foregroundStyle(AppTheme.primaryText)
            .padding(AppTheme.paddingMedium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                    .fill(AppTheme.parchment)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                    .stroke(AppTheme.burntOrange.opacity(0.22), lineWidth: 1)
            )
    }
}

struct NotesEditor: View {
    @Binding var text: String
    var placeholder: String = "A tip, a memory, or a swap"

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(AppTheme.body)
                .foregroundStyle(AppTheme.primaryText)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(.horizontal, AppTheme.paddingSmall)
                .padding(.vertical, AppTheme.paddingSmall)

            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .font(AppTheme.body)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .padding(.horizontal, AppTheme.paddingMedium + 1)
                    .padding(.vertical, AppTheme.paddingMedium + 8)
                    .allowsHitTesting(false)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .fill(AppTheme.parchment)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .stroke(AppTheme.burntOrange.opacity(0.22), lineWidth: 1)
        )
        .accessibilityLabel("Notes")
    }
}

struct NoticeBanner: View {
    let message: String
    var systemImage: String = "info.circle"
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.paddingSmall) {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.burntOrange)
                .accessibilityHidden(true)
            Text(message)
                .font(AppTheme.caption)
                .foregroundStyle(AppTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let onDismiss {
                Button("Dismiss", action: onDismiss)
                    .font(AppTheme.caption)
                    .foregroundStyle(AppTheme.burntOrange)
                    .frame(minHeight: 44)
            }
        }
        .padding(AppTheme.paddingMedium)
        .background(AppTheme.bannerFill)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        .accessibilityIdentifier("notice-banner")
    }
}

struct RecipeThumbnail: View {
    let data: Data?
    var systemImage: String = "fork.knife"
    var iconID: String? = nil
    var iconIDs: [String] = []

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                AppTheme.parchment
                content(in: size)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        // Photos must not propose their pixel size or they widen one grid column.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
        } else if !iconIDs.filter({ !$0.isEmpty }).isEmpty || !(iconID ?? "").isEmpty {
            let side = min(size.width, size.height) * 0.78
            let elements = iconIDs.filter { !$0.isEmpty }
            if elements.count > 1 {
                FoodIconView(iconIDs: elements, size: side)
            } else {
                FoodIconView(iconID: elements.first ?? iconID ?? "", size: side)
            }
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(AppTheme.burntOrange)
        }
    }
}

struct EmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    var illustration: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppTheme.paddingLarge) {
            if let illustration, !illustration.isEmpty {
                FoodIconView(iconID: illustration, size: 120)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(AppTheme.burntOrange)
                    .accessibilityHidden(true)
            }

            VStack(spacing: AppTheme.paddingSmall) {
                Text(title)
                    .font(AppTheme.title)
                    .foregroundStyle(AppTheme.primaryText)
                    .multilineTextAlignment(.center)
                if !message.isEmpty {
                    Text(message)
                        .font(AppTheme.body)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppTheme.paddingLarge)
                }
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct ColorChip: View {
    let title: String
    let selected: Bool
    /// Kept for call-site compatibility; selection always uses the brand orange palette.
    var color: Color = AppTheme.burntOrange
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.caption.weight(.semibold))
                .foregroundStyle(selected ? Color.white : AppTheme.primaryText)
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .background(selected ? AppTheme.burntOrange : AppTheme.cardBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        selected ? AppTheme.burntOrange : AppTheme.burntOrange.opacity(0.22),
                        lineWidth: 1
                    )
                )
                .shadow(color: selected ? AppTheme.burntOrange.opacity(0.28) : .clear, radius: 6, y: 2)
        }
        .buttonStyle(ChipButtonStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct ChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
