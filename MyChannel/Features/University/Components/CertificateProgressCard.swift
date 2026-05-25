//
//  CertificateProgressCard.swift
//  MyChannel
//
//  Beautiful Certificate Progress Cards with Circular Progress Rings
//  Premium modern design showing path to certificate
//

import SwiftUI

struct CertificateProgressCard: View {
    let careerPath: CareerPath
    let progress: CareerPathProgress
    let onTap: () -> Void
    
    @State private var animateProgress = false
    @State private var isPressed = false
    @State private var isHovered = false
    @Environment(\.sizeCategory) var sizeCategory
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .medium)
            onTap()
        }) {
            VStack(spacing: dynamicSpacing) {
                // Progress Ring
                progressRingSection
                
                // Career Info
                careerInfoSection
                
                // Progress Stats
                progressStatsSection
            }
            .padding(dynamicPadding)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.03 : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isHovered)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            withAnimation(.spring(response: 1.2, dampingFraction: 0.7).delay(0.1)) {
                animateProgress = true
            }
        }
        // 🔥 ACCESSIBILITY: Comprehensive VoiceOver support
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityCardLabel)
        .accessibilityHint("Double tap to view full career path details and certificate requirements")
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(accessibilityProgressValue)
    }
    
    // MARK: - Dynamic Sizing for Accessibility
    
    private var dynamicSpacing: CGFloat {
        sizeCategory.isAccessibilityCategory ? 20 : 16
    }
    
    private var dynamicPadding: CGFloat {
        sizeCategory.isAccessibilityCategory ? 24 : 20
    }
    
    private var ringSize: CGFloat {
        sizeCategory.isAccessibilityCategory ? 140 : 120
    }
    
    // MARK: - Accessibility Labels
    
    private var accessibilityCardLabel: String {
        "\(careerPath.name) certificate progress"
    }
    
    private var accessibilityProgressValue: String {
        let progressText = "\(progress.progressPercentage)% complete"
        let videosText = "\(progress.videosWatched) videos watched"
        let hoursText = "\(Int(progress.totalHours)) hours completed"
        let scoreText = "AI score \(progress.averageAIScore)"
        
        if progress.certificateEarned {
            return "Certificate earned. \(videosText), \(hoursText), \(scoreText)"
        } else {
            return "\(progressText), \(progress.videosRemaining) videos remaining. \(videosText), \(hoursText), \(scoreText)"
        }
    }
    
    // MARK: - Progress Ring Section
    
    private var progressRingSection: some View {
        ZStack {
            // 🔥 NEW: Use AnimatedProgressRing component with spring animations
            AnimatedProgressRing(
                progress: progress.certificateProgress,
                lineWidth: 12,
                primaryColor: Color(.label).opacity(0.7),
                label: "",
                showPercentage: false
            )
            .frame(width: ringSize, height: ringSize)
            
            // Inner Content with Career Icon
            VStack(spacing: sizeCategory.isAccessibilityCategory ? 6 : 4) {
                // Career Icon
                Image(systemName: careerPath.icon)
                    .font(.system(size: ringSize * 0.23, weight: .semibold))
                    .foregroundColor(Color(.label))
                
                // Percentage
                Text("\(progress.progressPercentage)%")
                    .font(.system(size: ringSize * 0.17, weight: .bold))
                    .foregroundColor(Color(.label))
            }
            .accessibilityHidden(true) // Progress announced at card level
        }
    }
    
    // MARK: - Career Info Section

    private var careerInfoSection: some View {
        VStack(spacing: 5) {
            Text(careerPath.name)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color(.label))
                .multilineTextAlignment(.center)
                .lineLimit(sizeCategory.isAccessibilityCategory ? nil : 2)
                .minimumScaleFactor(0.85)
                .accessibilityAddTraits(.isHeader)

            if progress.certificateEarned {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Earned")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(UniversityTheme.Colors.verified)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Certificate earned")
            } else {
                Text("\(progress.videosRemaining) videos left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(.secondaryLabel))
            }
        }
    }
    
    // MARK: - Progress Stats Section
    
    private var progressStatsSection: some View {
        HStack(spacing: 0) {
            statColumn(icon: "play.circle.fill", value: "\(progress.videosWatched)", label: "Videos")
            Divider().frame(height: 36)
            statColumn(icon: "clock.fill", value: "\(Int(progress.totalHours))h", label: "Hours")
            Divider().frame(height: 36)
            statColumn(icon: "checkmark.shield.fill", value: "\(progress.averageAIScore)", label: "AI Score")
        }
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func statColumn(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(.secondaryLabel))
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color(.label))
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Certificate Progress Grid

struct CertificateProgressGrid: View {
    let careerPathsProgress: [(careerPath: CareerPath, progress: CareerPathProgress)]
    let onTap: (CareerPath, CareerPathProgress) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "seal.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(UniversityTheme.Colors.accent)

                Text("Certificate Progress")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(.label))

                Spacer()

                // Total earned badges
                let earnedCount = careerPathsProgress.filter { $0.progress.certificateEarned }.count
                if earnedCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("\(earnedCount) Earned")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            
            // Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(careerPathsProgress, id: \.careerPath.id) { item in
                    CertificateProgressCard(
                        careerPath: item.careerPath,
                        progress: item.progress
                    ) {
                        onTap(item.careerPath, item.progress)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Compact Certificate Progress

struct CompactCertificateProgress: View {
    let careerPath: CareerPath
    let progress: CareerPathProgress

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color(.systemFill), lineWidth: 4)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(from: 0, to: progress.certificateProgress)
                    .stroke(Color(.label).opacity(0.7), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))

                Image(systemName: careerPath.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(.label))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(careerPath.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(.label))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(progress.progressPercentage)%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(.label))

                    Text("·")
                        .foregroundColor(Color(.tertiaryLabel))

                    Text("\(progress.videosWatched) videos")
                        .font(.system(size: 12))
                        .foregroundColor(Color(.secondaryLabel))
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
    }
}

// MARK: - ContentSizeCategory Extension

extension ContentSizeCategory {
    var isAccessibilityCategory: Bool {
        switch self {
        case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
             .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
            return true
        default:
            return false
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleCareerPath = CareerPath.allCareerPaths[0]
    let sampleProgress = CareerPathProgress(
        id: "1",
        userId: "user1",
        careerPathId: sampleCareerPath.id,
        totalHours: 187.5,
        videosWatched: 224,
        videoIds: [],
        lastWatchedAt: Date(),
        certificateProgress: 0.75,
        certificateEarned: false,
        certificateEarnedDate: nil,
        averageAIScore: 88,
        skillsCovered: ["Accounting", "Tax", "Excel", "Financial Analysis"]
    )
    
    let sampleData = CareerPath.allCareerPaths.prefix(4).map { path in
        (
            careerPath: path,
            progress: CareerPathProgress(
                id: path.id,
                userId: "user1",
                careerPathId: path.id,
                totalHours: Double.random(in: 50...250),
                videosWatched: Int.random(in: 50...280),
                videoIds: [],
                lastWatchedAt: Date(),
                certificateProgress: Double.random(in: 0.3...0.95),
                certificateEarned: Bool.random(),
                certificateEarnedDate: Bool.random() ? Date() : nil,
                averageAIScore: Int.random(in: 70...95),
                skillsCovered: []
            )
        )
    }
    
    ScrollView {
        VStack(spacing: 32) {
            CertificateProgressCard(
                careerPath: sampleCareerPath,
                progress: sampleProgress
            ) {
                print("Tapped certificate card")
            }
            .padding(.horizontal, 20)
            
            Divider()
            
            CertificateProgressGrid(careerPathsProgress: sampleData) { path, progress in
                print("Tapped: \(path.name)")
            }
            
            Divider()
            
            VStack(spacing: 12) {
                ForEach(Array(sampleData.prefix(3)), id: \.careerPath.id) { item in
                    CompactCertificateProgress(
                        careerPath: item.careerPath,
                        progress: item.progress
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 24)
    }
    .background(Color(.systemBackground))
}

