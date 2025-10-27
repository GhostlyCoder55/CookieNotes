//
//  LoginPromptView.swift
//  CookieNotes
//
//  Created by Christopher Ogbonnaya on 2025-10-26.
//

import SwiftUI

struct LoginPromptView: View {
    @ObservedObject var notificationManager: NotificationManager
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: AppTheme.paddingLarge) {
            // Icon
            Image(systemName: "heart.fill")
                .font(.system(size: 50))
                .foregroundColor(AppTheme.secondaryBrown)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
            
            // Title
            Text("Welcome Back!")
                .font(AppTheme.largeTitle)
                .foregroundColor(AppTheme.primaryText)
                .multilineTextAlignment(.center)
            
            // Message
            Text("We've missed you! Your recipe collection is waiting for you. Add some new recipes or revisit your favorites.")
                .font(AppTheme.body)
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            
            // Time since last visit
            if let lastLogin = notificationManager.lastLoginDate {
                Text("Last visit: \(lastLogin, style: .date)")
                    .font(AppTheme.caption)
                    .foregroundColor(AppTheme.tertiaryText)
            }
            
            // Buttons
            VStack(spacing: AppTheme.paddingMedium) {
                Button(action: {
                    notificationManager.markUserAsActive()
                }) {
                    HStack {
                        Image(systemName: "cookpot.fill")
                        Text("Start Cooking")
                    }
                    .font(AppTheme.headline)
                    .foregroundColor(AppTheme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(AppTheme.paddingMedium)
                    .background(AppTheme.secondaryBrown)
                    .cornerRadius(AppTheme.cornerRadiusMedium)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    notificationManager.dismissPrompt()
                }) {
                    Text("Maybe Later")
                        .font(AppTheme.body)
                        .foregroundColor(AppTheme.secondaryText)
                        .padding(AppTheme.paddingSmall)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(AppTheme.paddingXLarge)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadiusLarge)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .stroke(AppTheme.surfaceBackground, lineWidth: 1)
        )
        .shadow(color: AppTheme.cardShadow, radius: 10, x: 0, y: 5)
        .onAppear {
            isAnimating = true
        }
    }
}

struct LoginPromptOverlay: View {
    @ObservedObject var notificationManager: NotificationManager
    
    var body: some View {
        if notificationManager.shouldShowLoginPrompt {
            ZStack {
                // Background overlay
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        notificationManager.dismissPrompt()
                    }
                
                // Login prompt
                LoginPromptView(notificationManager: notificationManager)
                    .padding(AppTheme.paddingLarge)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: notificationManager.shouldShowLoginPrompt)
        }
    }
}

#Preview {
    LoginPromptOverlay(notificationManager: NotificationManager())
        .background(AppTheme.background)
}
