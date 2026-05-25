//
//  MyChannelPlusBenefitsView.swift
//  MyChannel
//
//  Created by AI Assistant
//

import SwiftUI

struct MyChannelPlusBenefitsView: View {
    @StateObject private var viewModel = MyChannelPlusBenefitsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingBenefitsExpanded = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Premium Header Section
                        premiumHeaderSection
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        
                        // Benefits Stats Section
                        benefitsStatsSection
                            .padding(.top, 32)
                        
                        // Experimental Features Card
                        experimentalFeaturesCard
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                        
                        // Explore Benefits Section
                        exploreBenefitsSection
                            .padding(.top, 32)
                        
                        Spacer(minLength: 40)
                    }
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Premium benefits")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 20) {
                        Button(action: {}) {
                            Image(systemName: "airplayvideo")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.loadBenefitsData()
        }
    }
    
    // MARK: - Premium Header Section
    
    private var premiumHeaderSection: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                // Premium Badge
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Plus")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    LinearGradient(
                        colors: [
                            AppTheme.Colors.primary,
                            AppTheme.Colors.primary.opacity(0.8)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                
                // Username
                if let user = viewModel.currentUser {
                    Text(user.username)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    // Member Since
                    if let memberSince = viewModel.memberSince {
                        Text("Member since \(formatDate(memberSince))")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }
            
            Spacer()
            
            // Profile Avatar
            if let user = viewModel.currentUser {
                AsyncImage(url: URL(string: user.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(AppTheme.Colors.primary)
                        .overlay(
                            Text(user.username.prefix(1).uppercased())
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
            }
        }
    }
    
    // MARK: - Benefits Stats Section
    
    private var benefitsStatsSection: some View {
        VStack(spacing: 0) {
            // Section Header
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showingBenefitsExpanded.toggle()
                }
            }) {
                HStack {
                    Text("Premium benefits enjoyed so far")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: showingBenefitsExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            
            if showingBenefitsExpanded {
                VStack(spacing: 0) {
                    // Ad-free videos
                    benefitRow(
                        icon: "play.rectangle.fill",
                        title: "Ad-free videos",
                        value: "> \(viewModel.stats.adFreeHours) hrs"
                    )
                    
                    Divider()
                        .padding(.leading, 60)
                    
                    // Background play
                    benefitRow(
                        icon: "headphones",
                        title: "Background play",
                        value: "> \(viewModel.stats.backgroundPlayHours) hrs"
                    )
                    
                    Divider()
                        .padding(.leading, 60)
                    
                    // Videos downloaded
                    benefitRow(
                        icon: "arrow.down.circle",
                        title: "Videos downloaded",
                        value: "\(viewModel.stats.videosDownloaded) videos"
                    )
                    
                    Divider()
                        .padding(.leading, 60)
                    
                    // Live streams watched
                    benefitRow(
                        icon: "dot.radiowaves.left.and.right",
                        title: "Live streams watched",
                        value: "\(viewModel.stats.liveStreamsWatched) streams"
                    )
                    
                    Divider()
                        .padding(.leading, 60)
                    
                    // VS Matches participated
                    benefitRow(
                        icon: "trophy.fill",
                        title: "VS Matches participated",
                        value: "\(viewModel.stats.vsMatchesParticipated) matches"
                    )
                    
                    Divider()
                        .padding(.leading, 60)
                    
                    // Exclusive content watched
                    benefitRow(
                        icon: "crown.fill",
                        title: "Exclusive content watched",
                        value: "> \(viewModel.stats.exclusiveContentHours) hrs"
                    )
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }
        }
        .background(AppTheme.Colors.surface)
    }
    
    private func benefitRow(icon: String, title: String, value: String) -> some View {
        Button(action: {}) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(AppTheme.Colors.surface)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Experimental Features Card
    
    private var experimentalFeaturesCard: some View {
        Button(action: {}) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.purple,
                                    Color.pink
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "star.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Try experimental new features")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("2 available, for a limited time")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textTertiary)
            }
            .padding(16)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Explore Benefits Section
    
    private var exploreBenefitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Explore benefits and offers")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("Get more out of your Plus membership")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .padding(.horizontal, 20)
            
            // Benefits Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.benefits) { benefit in
                        benefitCard(benefit)
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
        }
    }
    
    private func benefitCard(_ benefit: MyChannelPlusBenefit) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image
            AsyncImage(url: URL(string: benefit.imageURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(AppTheme.Colors.surface)
            }
            .frame(width: 280, height: 180)
            .clipped()
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(benefit.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(2)
                
                Text(benefit.description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
            .padding(12)
        }
        .frame(width: 280)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview("MyChannel Plus Benefits") {
    MyChannelPlusBenefitsView()
}

#Preview("MyChannel Plus Benefits - Dark Mode") {
    MyChannelPlusBenefitsView()
        .preferredColorScheme(.dark)
}

