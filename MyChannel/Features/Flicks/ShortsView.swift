//
//  ShortsView.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

struct ShortsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("🎬")
                .font(.system(size: 60))
            
            Text("Shorts")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text("Short-form videos coming soon!")
                .font(.title2)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background)
        .navigationTitle("Shorts")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationView {
        ShortsView()
    }
}