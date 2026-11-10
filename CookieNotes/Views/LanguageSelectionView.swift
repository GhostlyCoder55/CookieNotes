//
//  LanguageSelectionView.swift
//  CookieNotes
//

import SwiftUI

struct LanguageSelectionView: View {
    @ObservedObject private var languageManager = AppLanguageManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            VStack(spacing: 28) {
                VStack(spacing: 6) {
                    Text(String.localized("Choose your language"))
                        .font(AppTheme.title)
                        .foregroundStyle(AppTheme.primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                        .minimumScaleFactor(0.78)
                        .accessibilityAddTraits(.isHeader)

                    Text(String.localized("You can change the language anytime."))
                        .font(AppTheme.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                        .minimumScaleFactor(0.78)
                }
                .frame(maxWidth: 360)

                HStack(spacing: 18) {
                    languageSquareCard(language: .english)
                    languageSquareCard(language: .french)
                }
                .frame(maxWidth: 360)
            }
            .padding(.horizontal, AppTheme.paddingLarge)

            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.selection, trigger: languageManager.currentLanguage)
    }

    private func languageSquareCard(language: AppLanguage) -> some View {
        let isSelected = languageManager.currentLanguage == language
        let cardShape = RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)

        return Button {
            if reduceMotion {
                languageManager.setLanguage(language)
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    languageManager.setLanguage(language)
                }
            }
        } label: {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    VStack(spacing: 12) {
                        HexagonFlagBadge(language: language)
                            .frame(width: 72, height: 82)

                        Text(verbatim: language.displayName)
                            .font(AppTheme.headline)
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .padding(12)
                }
                .background(
                    ZStack {
                        AppTheme.cardBackground
                        if isSelected {
                            AppTheme.burntOrange.opacity(0.14)
                        }
                    }
                )
                .clipShape(cardShape)
                .overlay(
                    cardShape.stroke(
                        isSelected ? AppTheme.burntOrange : AppTheme.separator.opacity(0.35),
                        lineWidth: isSelected ? 2.5 : 1
                    )
                )
                .shadow(
                    color: isSelected ? AppTheme.burntOrange.opacity(0.24) : AppTheme.cardShadow,
                    radius: isSelected ? 10 : 5,
                    y: 3
                )
                .contentShape(cardShape)
        }
        .buttonStyle(CardButtonStyle())
        .accessibilityIdentifier("language-option-\(language.code)")
        .accessibilityLabel(Text(verbatim: language.displayName))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct RoundedHexagon: Shape {
    var cornerRadius: CGFloat = 7

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width / CGFloat(sqrt(3.0)), rect.height / 2)
        guard radius > 0 else { return Path() }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let vertices: [CGPoint] = (0..<6).map { index in
            let angle = (CGFloat(index) * 60.0 - 90.0) * .pi / 180.0
            return CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
        }

        let clampedRadius = min(cornerRadius, radius * 0.45)

        var path = Path()
        let initialMidpoint = CGPoint(
            x: (vertices[5].x + vertices[0].x) / 2,
            y: (vertices[5].y + vertices[0].y) / 2
        )
        path.move(to: initialMidpoint)
        for index in 0..<6 {
            let current = vertices[index]
            let next = vertices[(index + 1) % 6]
            path.addArc(tangent1End: current, tangent2End: next, radius: clampedRadius)
        }
        path.closeSubpath()
        return path
    }
}

private struct HexagonFlagBadge: View {
    let language: AppLanguage

    var body: some View {
        let shape = RoundedHexagon(cornerRadius: 7)

        Group {
            switch language {
            case .english:
                unionJackFlag
            case .french:
                frenchTricolourFlag
            }
        }
        .clipShape(shape)
        .overlay(
            shape.stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 4, y: 2)
        .accessibilityHidden(true)
    }

    private var frenchTricolourFlag: some View {
        HStack(spacing: 0) {
            Color(red: 0.0 / 255.0, green: 85.0 / 255.0, blue: 164.0 / 255.0)
            Color.white
            Color(red: 239.0 / 255.0, green: 65.0 / 255.0, blue: 53.0 / 255.0)
        }
    }

    private var unionJackFlag: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let s = min(w, h)
            let radius = min(w / CGFloat(sqrt(3.0)), h / 2)
            let center = CGPoint(x: w / 2, y: h / 2)
            let dx = radius * CGFloat(sqrt(3.0)) / 2 * 1.2
            let dy = (radius / 2) * 1.2

            let navy = Color(red: 1.0 / 255.0, green: 33.0 / 255.0, blue: 105.0 / 255.0)
            let red = Color(red: 200.0 / 255.0, green: 16.0 / 255.0, blue: 46.0 / 255.0)

            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(navy))

            var diag1 = Path()
            diag1.move(to: CGPoint(x: center.x - dx, y: center.y - dy))
            diag1.addLine(to: CGPoint(x: center.x + dx, y: center.y + dy))

            var diag2 = Path()
            diag2.move(to: CGPoint(x: center.x + dx, y: center.y - dy))
            diag2.addLine(to: CGPoint(x: center.x - dx, y: center.y + dy))

            context.stroke(diag1, with: .color(.white), lineWidth: s * 0.17)
            context.stroke(diag2, with: .color(.white), lineWidth: s * 0.17)
            context.stroke(diag1, with: .color(red), lineWidth: s * 0.075)
            context.stroke(diag2, with: .color(red), lineWidth: s * 0.075)

            let whiteCross = s * 0.27
            context.fill(
                Path(CGRect(x: (w - whiteCross) / 2, y: 0, width: whiteCross, height: h)),
                with: .color(.white)
            )
            context.fill(
                Path(CGRect(x: 0, y: (h - whiteCross) / 2, width: w, height: whiteCross)),
                with: .color(.white)
            )

            let redCross = s * 0.16
            context.fill(
                Path(CGRect(x: (w - redCross) / 2, y: 0, width: redCross, height: h)),
                with: .color(red)
            )
            context.fill(
                Path(CGRect(x: 0, y: (h - redCross) / 2, width: w, height: redCross)),
                with: .color(red)
            )
        }
    }
}

#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        LanguageSelectionView()
    }
    .preferredColorScheme(.dark)
}
