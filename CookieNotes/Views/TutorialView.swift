//
//  TutorialView.swift
//  CookieNotes
//

import SwiftUI

/// First-launch tips — shown once for new users, like Apple system tips.
struct TutorialView: View {
    @ObservedObject var tutorialManager: TutorialManager
    @Binding var isPresented: Bool
    @State private var currentStep = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let steps: [TutorialStep] = [
        TutorialStep(
            title: "Welcome to CookieNotes",
            headline: ("Welcome to", "CookieNotes"),
            description: "Keep recipes, discover new ones, and cook with confidence.",
            icon: "veggie_plate"
        ),
        TutorialStep(
            title: "Library",
            description: "Your personal cookbook lives here. Favorite recipes, filter by meal, and open cook mode when you’re ready.",
            icon: "salad_bowl"
        ),
        TutorialStep(
            title: "Discover",
            description: "Search online recipes, preview ingredients and steps, then save keepers to your library.",
            icon: "pepperoni_pizza"
        ),
        TutorialStep(
            title: "Ingredient art",
            headline: ("Ingredient", "art"),
            description: "Browse colourful food art when adding ingredients, or type a custom item anytime.",
            icon: "tomatoes_vine"
        ),
        TutorialStep(
            title: "You’re all set",
            description: "Add a recipe you know by heart, or discover something new. Happy cooking!",
            icon: "cupcake"
        )
    ]

    private var isLastStep: Bool { currentStep >= steps.count - 1 }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip", action: finish)
                        .font(AppTheme.body.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)

                TabView(selection: $currentStep) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        tipPage(step)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: currentStep)

                pageIndicators
                    .padding(.bottom, 20)

                Button(action: advance) {
                    Text(isLastStep ? "Get Started" : "Continue")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, AppTheme.paddingLarge)
                .padding(.bottom, 28)
                .accessibilityLabel(isLastStep ? "Get Started" : "Continue")
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
    }

    private func tipPage(_ step: TutorialStep) -> some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)

            FoodIconView(iconID: step.icon, size: 148)
                .padding(20)
                .background(AppTheme.parchment)
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                .frame(maxWidth: .infinity)

            VStack(spacing: 10) {
                if let headline = step.headline {
                    VStack(spacing: 2) {
                        Text(headline.0)
                        Text(headline.1)
                    }
                    .font(AppTheme.largeTitle)
                    .foregroundStyle(AppTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                } else {
                    Text(step.title)
                        .font(AppTheme.largeTitle)
                        .foregroundStyle(AppTheme.primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity)
                }

                Text(step.description)
                    .font(AppTheme.body)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, AppTheme.paddingLarge)

            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pageIndicators: some View {
        HStack(spacing: 8) {
            ForEach(0..<steps.count, id: \.self) { index in
                Capsule()
                    .fill(index == currentStep ? AppTheme.burntOrange : AppTheme.separator)
                    .frame(width: index == currentStep ? 22 : 8, height: 8)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: currentStep)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tip \(currentStep + 1) of \(steps.count)")
    }

    private func advance() {
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
        tutorialManager.completeTutorial()
        isPresented = false
    }
}

struct TutorialStep {
    let title: String
    /// Optional two-line headline kept centered as a pair (welcome screen).
    var headline: (String, String)? = nil
    let description: String
    let icon: String
}

#Preview {
    TutorialView(tutorialManager: TutorialManager(), isPresented: .constant(true))
}
