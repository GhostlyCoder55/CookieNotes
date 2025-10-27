//
//  AppTheme.swift
//  CookieNotes
//
//  Created by Christopher Ogbonnaya on 2025-10-26.
//

import SwiftUI

struct AppTheme {
    // Primary Colors
    static let primaryBlack = Color(red: 0.05, green: 0.05, blue: 0.05)
    static let secondaryBrown = Color(red: 0.6, green: 0.4, blue: 0.2)
    static let accentBrown = Color(red: 0.7, green: 0.5, blue: 0.3)
    static let lightBrown = Color(red: 0.8, green: 0.6, blue: 0.4)
    
    // Text Colors
    static let primaryText = Color.white
    static let secondaryText = Color(red: 0.8, green: 0.8, blue: 0.8)
    static let tertiaryText = Color(red: 0.6, green: 0.6, blue: 0.6)
    
    // Background Colors
    static let background = primaryBlack
    static let cardBackground = Color(red: 0.1, green: 0.1, blue: 0.1)
    static let surfaceBackground = Color(red: 0.15, green: 0.15, blue: 0.15)
    
    // Accent Colors
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    
    // Typography
    static let largeTitle = Font.system(size: 32, weight: .bold, design: .rounded)
    static let title = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let headline = Font.system(size: 20, weight: .medium, design: .rounded)
    static let body = Font.system(size: 16, weight: .regular, design: .rounded)
    static let caption = Font.system(size: 14, weight: .regular, design: .rounded)
    static let smallCaption = Font.system(size: 12, weight: .regular, design: .rounded)
    
    // Spacing
    static let paddingSmall: CGFloat = 8
    static let paddingMedium: CGFloat = 16
    static let paddingLarge: CGFloat = 24
    static let paddingXLarge: CGFloat = 32
    
    // Corner Radius
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 16
    
    // Shadows
    static let cardShadow = Color.black.opacity(0.3)
    static let buttonShadow = Color.black.opacity(0.2)
}

// Custom Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(AppTheme.primaryText)
            .padding(.horizontal, AppTheme.paddingMedium)
            .padding(.vertical, AppTheme.paddingSmall)
            .background(AppTheme.secondaryBrown)
            .cornerRadius(AppTheme.cornerRadiusMedium)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .shadow(color: AppTheme.buttonShadow, radius: 4, x: 0, y: 2)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(AppTheme.secondaryBrown)
            .padding(.horizontal, AppTheme.paddingMedium)
            .padding(.vertical, AppTheme.paddingSmall)
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cornerRadiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .stroke(AppTheme.secondaryBrown, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Card Style
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cornerRadiusMedium)
            .shadow(color: AppTheme.cardShadow, radius: 8, x: 0, y: 4)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
