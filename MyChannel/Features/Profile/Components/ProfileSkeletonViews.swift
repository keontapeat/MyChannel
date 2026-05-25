import SwiftUI

struct ProfileLoadingSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            // Header Skeleton
            ZStack {
                LinearGradient(
                    colors: [AppTheme.Colors.primary.opacity(0.6), AppTheme.Colors.secondary.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 365)
                .overlay(
                    Rectangle()
                        .fill(.black.opacity(0.25))
                )

                VStack(spacing: 16) {
                    Circle()
                        .fill(AppTheme.Colors.surface.opacity(0.6))
                        .frame(width: 80, height: 80)
                        .overlay(SkeletonView().clipShape(Circle()))
                        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppTheme.Colors.surface.opacity(0.6))
                        .frame(width: 160, height: 18)
                        .overlay(SkeletonView().clipShape(RoundedRectangle(cornerRadius: 6)))

                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppTheme.Colors.surface.opacity(0.5))
                        .frame(width: 220, height: 12)
                        .overlay(SkeletonView().clipShape(RoundedRectangle(cornerRadius: 6)))

                    HStack(spacing: 24) {
                        ForEach(0..<3, id: \.self) { _ in
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(AppTheme.Colors.surface.opacity(0.5))
                                    .frame(width: 48, height: 14)
                                    .overlay(SkeletonView().clipShape(RoundedRectangle(cornerRadius: 6)))

                                RoundedRectangle(cornerRadius: 6)
                                    .fill(AppTheme.Colors.surface.opacity(0.4))
                                    .frame(width: 48, height: 10)
                                    .overlay(SkeletonView().clipShape(RoundedRectangle(cornerRadius: 6)))
                            }
                        }
                    }
                    .padding(.top, 6)
                }
                .foregroundStyle(.white)
            }

            // Tabs Skeleton
            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.Colors.surface)
                        .frame(width: 90, height: 34)
                        .overlay(SkeletonView().clipShape(RoundedRectangle(cornerRadius: 10)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .overlay(
                Rectangle()
                    .fill(AppTheme.Colors.textSecondary.opacity(0.1))
                    .frame(height: 0.5),
                alignment: .bottom
            )

            // Grid Skeleton
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ], spacing: 12) {
                    ForEach(0..<6, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppTheme.Colors.surface)
                                .frame(height: 110)
                                .overlay(SkeletonView().clipShape(RoundedRectangle(cornerRadius: 8)))

                            RoundedRectangle(cornerRadius: 6)
                                .fill(AppTheme.Colors.surface)
                                .frame(height: 14)
                                .overlay(SkeletonView().clipShape(RoundedRectangle(cornerRadius: 6)))

                            RoundedRectangle(cornerRadius: 6)
                                .fill(AppTheme.Colors.surface.opacity(0.9))
                                .frame(width: 120, height: 12)
                                .overlay(SkeletonView().clipShape(RoundedRectangle(cornerRadius: 6)))
                        }
                        .padding(8)
                        .background(AppTheme.Colors.surface)
                        .cornerRadius(12)
                        .shadow(color: AppTheme.Colors.textPrimary.opacity(0.06), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
        }
        .background(AppTheme.Colors.background)
    }
}

#Preview("Profile Loading Skeleton") {
    ProfileLoadingSkeleton()
        .environmentObject(AppState())
}