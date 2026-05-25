//
//  ShimmerLoadingViews.swift
//  MyChannel
//
//  🔥 NUCLEAR: Shimmer loading states for University
//  Professional skeleton loading with smooth animations
//

import SwiftUI

// MARK: - Shimmer Modifier

extension View {
}

// MARK: - Video Card Skeleton

struct VideoCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Thumbnail skeleton
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.surface)
                .frame(height: 157)
                .shimmer()
            
            // Title skeleton
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppTheme.Colors.surface)
                    .frame(height: 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .shimmer()
                
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppTheme.Colors.surface)
                    .frame(width: 180, height: 16)
                    .shimmer()
            }
            
            // Creator skeleton
            HStack(spacing: 8) {
                Circle()
                    .fill(AppTheme.Colors.surface)
                    .frame(width: 24, height: 24)
                    .shimmer()
                
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppTheme.Colors.surface)
                    .frame(width: 100, height: 12)
                    .shimmer()
            }
            
            // Tags skeleton
            HStack(spacing: 6) {
                ForEach(0..<3) { _ in
                    Capsule()
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 60, height: 22)
                        .shimmer()
                }
            }
        }
        .frame(width: 280)
        .padding(12)
        .background(AppTheme.Colors.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Certificate Progress Card Skeleton

struct CertificateProgressCardSkeleton: View {
    var body: some View {
        VStack(spacing: 16) {
            // Progress ring skeleton
            Circle()
                .stroke(AppTheme.Colors.surface, lineWidth: 12)
                .frame(width: 120, height: 120)
                .shimmer()
            
            // Title skeleton
            RoundedRectangle(cornerRadius: 6)
                .fill(AppTheme.Colors.surface)
                .frame(width: 140, height: 18)
                .shimmer()
            
            // Subtitle skeleton
            RoundedRectangle(cornerRadius: 6)
                .fill(AppTheme.Colors.surface)
                .frame(width: 100, height: 14)
                .shimmer()
            
            // Stats skeleton
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { index in
                    VStack(spacing: 6) {
                        Circle()
                            .fill(AppTheme.Colors.surface)
                            .frame(width: 16, height: 16)
                            .shimmer()
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.Colors.surface)
                            .frame(width: 40, height: 16)
                            .shimmer()
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.Colors.surface)
                            .frame(width: 50, height: 10)
                            .shimmer()
                    }
                    .frame(maxWidth: .infinity)
                    
                    if index < 2 {
                        Divider()
                            .frame(height: 40)
                    }
                }
            }
            .padding(.vertical, 12)
            .background(AppTheme.Colors.surface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(20)
        .background(AppTheme.Colors.surface.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Career Path Row Skeleton

struct CareerPathRowSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header skeleton
            HStack(spacing: 12) {
                Circle()
                    .fill(AppTheme.Colors.surface)
                    .frame(width: 44, height: 44)
                    .shimmer()
                
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 180, height: 18)
                        .shimmer()
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 140, height: 14)
                        .shimmer()
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Video cards skeleton
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<3) { _ in
                        VideoCardSkeleton()
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Hero Card Skeleton

struct HeroCardSkeleton: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.Colors.surface.opacity(0.5),
                            AppTheme.Colors.surface.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 220)
            
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 50, height: 50)
                        .shimmer()
                    
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppTheme.Colors.surface)
                            .frame(width: 180, height: 22)
                            .shimmer()
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppTheme.Colors.surface)
                            .frame(width: 140, height: 14)
                            .shimmer()
                    }
                }
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppTheme.Colors.surface)
                            .frame(width: 100, height: 36)
                            .shimmer()
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppTheme.Colors.surface)
                            .frame(width: 120, height: 12)
                            .shimmer()
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 8) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppTheme.Colors.surface)
                            .frame(width: 60, height: 32)
                            .shimmer()
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppTheme.Colors.surface)
                            .frame(width: 110, height: 12)
                            .shimmer()
                    }
                }
                
                Capsule()
                    .fill(AppTheme.Colors.surface)
                    .frame(height: 36)
                    .shimmer()
            }
            .padding(24)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 32) {
            Text("Video Card Skeleton")
                .font(.headline)
            VideoCardSkeleton()
            
            Divider()
            
            Text("Certificate Progress Card Skeleton")
                .font(.headline)
            CertificateProgressCardSkeleton()
            
            Divider()
            
            Text("Career Path Row Skeleton")
                .font(.headline)
            CareerPathRowSkeleton()
            
            Divider()
            
            Text("Hero Card Skeleton")
                .font(.headline)
            HeroCardSkeleton()
        }
        .padding(.vertical, 24)
    }
    .background(AppTheme.Colors.background)
}

