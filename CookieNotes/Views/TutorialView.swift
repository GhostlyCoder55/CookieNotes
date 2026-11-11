//
//  TutorialView.swift
//  CookieNotes
//

import SwiftUI

/// First-launch tips — shown once for new users, starting with language selection.
struct TutorialView: View {
    @ObservedObject var tutorialManager: TutorialManager
    @Binding var isPresented: Bool
    @ObservedObject private var languageManager = AppLanguageManager.shared
    @State private var currentStep = 0
    // Intentionally seeded once on appear so completing step 0 does not collapse the pager mid-flow.
    @State private var includesLanguageStep: Bool
    @State private var includesTipsSteps: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        tutorialManager: TutorialManager,
        isPresented: Binding<Bool>,
        includesLanguageStep: Bool = !AppLanguageManager.shared.hasSelectedInitialLanguage && !LaunchOptions.skipLanguageSelection,
        includesTipsSteps: Bool? = nil
    ) {
        self.tutorialManager = tutorialManager
        self._isPresented = isPresented
        self._includesLanguageStep = State(initialValue: includesLanguageStep)
        self._includesTipsSteps = State(initialValue: includesTipsSteps ?? tutorialManager.shouldShowFirstRunTips)
    }

    private var steps: [TutorialStep] {
        [
            TutorialStep(
                id: 0,
                title: String.localized("Welcome to CookieNotes"),
                description: String.localized("Keep recipes, discover new ones, and cook with confidence."),
                artwork: .appLogo
            ),
            TutorialStep(
                id: 1,
                title: String.localized("Library"),
                description: String.localized("Your personal cookbook lives here. Favorite recipes, filter by meal, and open cook mode when you’re ready."),
                artwork: .foodIcon("salad_bowl")
            ),
            TutorialStep(
                id: 2,
                title: String.localized("Discover"),
                description: String.localized("Search online recipes, preview ingredients and steps, then save keepers to your library."),
                artwork: .foodIcon("pepperoni_pizza")
            ),
            TutorialStep(
                id: 3,
                title: String.localized("List"),
                description: String.localized("Keep a grocery checklist, check off items as you shop, and organize what you need."),
                artwork: .foodIcon("bread_loaf")
            ),
            TutorialStep(
                id: 4,
                title: String.localized("Ingredient art"),
                description: String.localized("Browse colourful food art when adding ingredients, or type a custom item anytime."),
                artwork: .foodIcon("tomatoes_vine")
            ),
            TutorialStep(
                id: 5,
                title: String.localized("You’re all set"),
                description: String.localized("Add a recipe you know by heart, or discover something new. Happy cooking!"),
                artwork: .foodIcon("cupcake")
            )
        ]
    }

    private var pageCount: Int {
        (includesLanguageStep ? 1 : 0) + (includesTipsSteps ? steps.count : 0)
    }

    private var isLastStep: Bool { currentStep >= max(pageCount - 1, 0) }

    private var primaryButtonTitle: String {
        if !includesTipsSteps && includesLanguageStep {
            return String.localized("Continue")
        }
        return isLastStep ? String.localized("Get Started") : String.localized("Continue")
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if pageCount > 1 {
                        Button(String.localized("Skip"), action: finish)
                            .font(AppTheme.body.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)

                TabView(selection: $currentStep) {
                    if includesLanguageStep {
                        LanguageSelectionView()
                            .tag(0)
                    }

                    if includesTipsSteps {
                        ForEach(steps) { step in
                            tipPage(step)
                                .tag(includesLanguageStep ? step.id + 1 : step.id)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: currentStep)
                .sensoryFeedback(.selection, trigger: currentStep)
                .onChange(of: currentStep) { _, newStep in
                    if includesLanguageStep && newStep > 0 && !languageManager.hasSelectedInitialLanguage {
                        languageManager.selectLanguage(languageManager.currentLanguage)
                    }
                }

                if pageCount > 1 {
                    pageIndicators
                        .padding(.top, AppTheme.paddingSmall)
                        .padding(.bottom, 20)
                }

                Button(action: advance) {
                    Text(primaryButtonTitle)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, AppTheme.paddingLarge)
                .padding(.bottom, 28)
                .accessibilityLabel(primaryButtonTitle)
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
    }

    private func tipPage(_ step: TutorialStep) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            VStack(spacing: 28) {
                tipArtwork(for: step.artwork)
                    .frame(height: 168)
                    .frame(maxWidth: .infinity)

                VStack(spacing: 6) {
                    Text(step.title)
                        .font(AppTheme.title)
                        .foregroundStyle(AppTheme.primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                        .minimumScaleFactor(0.78)
                        .accessibilityAddTraits(.isHeader)

                    Text(step.description)
                        .font(AppTheme.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(
                            maxWidth: 340,
                            minHeight: dynamicTypeSize.isAccessibilitySize ? nil : 56,
                            alignment: .top
                        )
                }
                .frame(maxWidth: 360)
            }
            .padding(.horizontal, AppTheme.paddingLarge)

            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func tipArtwork(for artwork: TutorialStep.Artwork) -> some View {
        switch artwork {
        case .appLogo:
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 136, height: 136)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .shadow(color: AppTheme.cardShadow, radius: 12, y: 6)
                .accessibilityHidden(true)
        case .foodIcon(let iconID):
            FoodIconView(iconID: iconID, size: 128)
                .padding(20)
                .background(AppTheme.parchment)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
    }

    private var pageIndicators: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == currentStep ? AppTheme.burntOrange : AppTheme.separator)
                    .frame(width: index == currentStep ? 22 : 8, height: 8)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: currentStep)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: String.localized("Tip %lld of %lld"), currentStep + 1, pageCount))
    }

    private func advance() {
        if includesLanguageStep && currentStep == 0 && !languageManager.hasSelectedInitialLanguage {
            languageManager.selectLanguage(languageManager.currentLanguage)
        }

        if isLastStep {
            finish()
        } else if reduceMotion {
            currentStep += 1
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentStep += 1
            }
        }
    }

    private func finish() {
        if !languageManager.hasSelectedInitialLanguage {
            languageManager.selectLanguage(languageManager.currentLanguage)
        }
        tutorialManager.completeTutorial()
        isPresented = false
    }
}

struct TutorialStep: Identifiable {
    enum Artwork {
        case appLogo
        case foodIcon(String)
    }

    let id: Int
    let title: String
    let description: String
    let artwork: Artwork
}

#Preview {
    TutorialView(
        tutorialManager: TutorialManager(),
        isPresented: .constant(true),
        includesLanguageStep: true,
        includesTipsSteps: true
    )
}
