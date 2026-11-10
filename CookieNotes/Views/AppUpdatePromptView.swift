//
//  AppUpdatePromptView.swift
//  CookieNotes
//
//  Clean, accessible, native SwiftUI update prompt conforming to
//  Apple Human Interface Guidelines and CookieNotes visual theme.
//

import SwiftUI

struct AppUpdatePromptCardView: View {
    let updateInfo: AppUpdateInfo
    let onUpdate: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: AppTheme.paddingLarge) {
            // Header Icon
            ZStack {
                Circle()
                    .fill(AppTheme.burntOrange.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: updateInfo.isMandatory ? "exclamationmark.shield.fill" : "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(AppTheme.burntOrange)
                    .scaleEffect(!reduceMotion && isPulsing ? 1.08 : 1.0)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                        value: isPulsing
                    )
            }
            .accessibilityHidden(true)
            .padding(.top, 4)

            // Title & Subtitle
            VStack(spacing: 8) {
                Text(updateInfo.title)
                    .font(AppTheme.title)
                    .foregroundStyle(AppTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(updateInfo.message)
                    .font(AppTheme.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Release Notes (if present)
            if let notes = updateInfo.releaseNotes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String.localized("What's New"))
                        .font(AppTheme.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)

                    ScrollView {
                        Text(notes)
                            .font(AppTheme.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxHeight: 110)
                }
                .padding(AppTheme.paddingMedium)
                .background(AppTheme.surfaceBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            }

            // Action Buttons
            VStack(spacing: 10) {
                Button(action: onUpdate) {
                    Label(String.localized("Update Now"), systemImage: "arrow.down.app.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityLabel(Text(String.localized("Update Now")))

                if !updateInfo.isMandatory {
                    Button(action: onDismiss) {
                        Text(String.localized("Maybe Later"))
                            .font(AppTheme.body)
                            .foregroundStyle(AppTheme.secondaryText)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(Text(String.localized("Maybe Later")))
                }
            }
            .padding(.top, 4)
        }
        .padding(AppTheme.paddingLarge)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .stroke(AppTheme.burntOrange.opacity(updateInfo.isMandatory ? 0.4 : 0.2), lineWidth: 1)
        )
        .shadow(color: AppTheme.cardShadow, radius: 18, y: 8)
        .onAppear {
            if !reduceMotion {
                isPulsing = true
            }
        }
    }
}

struct AppUpdatePromptOverlay: View {
    @ObservedObject private var updateManager = AppUpdateManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let info = updateManager.updateInfo {
            ZStack {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        if !info.isMandatory {
                            updateManager.dismissOptionalUpdate()
                        }
                    }

                AppUpdatePromptCardView(
                    updateInfo: info,
                    onUpdate: {
                        updateManager.performUpdate()
                    },
                    onDismiss: {
                        updateManager.dismissOptionalUpdate()
                    }
                )
                .padding(.horizontal, 24)
                .transition(reduceMotion ? .opacity : .scale(scale: 0.95).combined(with: .opacity))
            }
            .zIndex(100)
            .accessibilityAddTraits(.isModal)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: updateManager.updateInfo != nil)
        }
    }
}
