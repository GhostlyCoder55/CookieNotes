//
//  LaunchScreenView.swift
//  CookieNotes
//
//  Created by Christopher Ogbonnaya on 2025-10-26.
//

import SwiftUI

struct LaunchScreenView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background matching app theme
            AppTheme.background
                .ignoresSafeArea()
            
            // App Name in brown color - centered
            Text("CookieNotes")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.secondaryBrown)
                .opacity(isAnimating ? 1.0 : 0.0)
                .offset(y: isAnimating ? 0 : 20)
                .multilineTextAlignment(.center)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}
