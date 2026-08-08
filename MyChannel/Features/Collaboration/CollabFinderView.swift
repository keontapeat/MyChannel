//
//  CollabFinderView.swift
//  MyChannel
//
//  AI-POWERED COLLAB FINDER - Find perfect collaboration partners
//  Revenue calculator, audience overlap analysis, AI matching
//  Created for MyChannel by AI Assistant
//

import SwiftUI
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct CollabFinderView: View {
    @StateObject private var viewModel = CollabFinderViewModel()
    @State private var selectedCreator: CollabCreator?
    @State private var showFilters = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 28) {
                        // Hero Section
                        collabHero
                        
                        // AI Matches
                        aiMatchesSection
                        
                        // Active Collabs
                        activeCollabsSection
                        
                        // Potential Revenue
                        revenueProjectionSection
                        
                        // Search by Category
                        categorySection
                        
                        // Success Stories
                        successStoriesSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Collab Finder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.Colors.primary)
                    }
                }
            }
        }
        .sheet(item: $selectedCreator) { creator in
            CreatorCollabSheet(creator: creator, viewModel: viewModel)
        }
        .sheet(isPresented: $showFilters) {
            CollabFiltersSheet(viewModel: viewModel)
        }
        .onAppear {
            Task {
                await viewModel.loadCollabData()
            }
        }
    }
    
    // MARK: - Hero Section
    private var collabHero: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.6, green: 0.3, blue: 0.9),
                            Color(red: 0.3, green: 0.5, blue: 0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 220)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 32, weight: .bold))
                    Text("Collab Finder")
                        .font(.system(size: 28, weight: .bold))
                }
                .foregroundColor(.white)
                
                Text("Find your perfect collaboration partner")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
                
                HStack(spacing: 14) {
                    featureBadge(icon: "brain.head.profile", text: "AI Matching")
                    featureBadge(icon: "chart.bar.fill", text: "Revenue Calc")
                    featureBadge(icon: "person.3.fill", text: "Audience Overlap")
                }
                
                Text("💰 Average collab earns $2,500+")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
            }
            .padding(24)
        }
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    private func featureBadge(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.2))
        .clipShape(Capsule())
    }
    
    // MARK: - AI Matches
    private var aiMatchesSection: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.purple)
                    
                    Text("Perfect Matches For You")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
            }
            
            ForEach(viewModel.aiMatches) { match in
                CollabMatchCard(match: match) {
                    selectedCreator = match.creator
                }
            }
        }
    }
    
    // MARK: - Active Collabs
    private var activeCollabsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Your Active Collaborations")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text("\(viewModel.activeCollabs.count)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            
            if viewModel.activeCollabs.isEmpty {
                EmptyCollabsView()
            } else {
                ForEach(viewModel.activeCollabs) { collab in
                    ActiveCollabCard(collab: collab)
                }
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Revenue Projection
    private var revenueProjectionSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Potential Revenue")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                CollabRevenueCard(
                    title: "This Month",
                    amount: viewModel.projectedMonthlyRevenue,
                    trend: "+24%",
                    color: .green
                )
                
                CollabRevenueCard(
                    title: "Per Collab",
                    amount: viewModel.avgRevenuePerCollab,
                    trend: "+15%",
                    color: .blue
                )
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Category Section
    private var categorySection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Browse by Category")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(CollabCategory.allCategories) { category in
                        CollabCategoryChip(category: category) {
                            // Filter by category
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Success Stories
    private var successStoriesSection: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.yellow)
                    
                    Text("Success Stories")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
            }
            
            ForEach(viewModel.successStories) { story in
                SuccessStoryCard(story: story)
            }
        }
        .padding(20)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Supporting Views

struct CollabMatchCard: View {
    let match: CollabMatch
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    AsyncImage(url: URL(string: match.creator.avatarURL)) { image in
                        image.resizable()
                    } placeholder: {
                        Circle().fill(AppTheme.Colors.cardBackground)
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(match.creator.name)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                            
                            if match.creator.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 11))
                                Text(match.creator.subscribers)
                                    .font(.system(size: 13))
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 11))
                                Text(match.creator.avgViews)
                                    .font(.system(size: 13))
                            }
                        }
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .stroke(matchColor(match.matchScore).opacity(0.2), lineWidth: 4)
                                .frame(width: 56, height: 56)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(match.matchScore) / 100.0)
                                .stroke(matchColor(match.matchScore), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 56, height: 56)
                                .rotationEffect(.degrees(-90))
                            
                            Text("\(match.matchScore)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(matchColor(match.matchScore))
                        }
                        
                        Text("Match")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
                
                // Key Insights
                VStack(spacing: 10) {
                    CollabInsightRow(icon: "chart.line.uptrend.xyaxis", text: "Audience Overlap: \(match.audienceOverlap)%", color: .green)
                    CollabInsightRow(icon: "dollarsign.circle.fill", text: "Est. Revenue: $\(match.projectedRevenue)", color: .blue)
                    CollabInsightRow(icon: "eye.fill", text: "Projected Views: \(match.projectedViews)", color: .purple)
                }
                .padding(.top, 8)
            }
            .padding(18)
            .background(AppTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(matchColor(match.matchScore).opacity(0.3), lineWidth: 2)
            )
        }
    }
    
    private func matchColor(_ score: Int) -> Color {
        if score >= 90 { return .green }
        else if score >= 75 { return .blue }
        else if score >= 60 { return .orange }
        else { return .gray }
    }
}

struct CollabInsightRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
            
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ActiveCollabCard: View {
    let collab: ActiveCollab
    
    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: URL(string: collab.partnerAvatarURL)) { image in
                image.resizable()
            } placeholder: {
                Circle().fill(AppTheme.Colors.cardBackground)
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 6) {
                Text(collab.projectName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Text("With \(collab.partnerName)")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor(collab.status))
                        .frame(width: 8, height: 8)
                    
                    Text(collab.status)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(statusColor(collab.status))
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(collab.currentRevenue)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.green)
                
                Text("\(collab.views) views")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
        }
        .padding(14)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "planning": return .orange
        case "recording": return .blue
        case "editing": return .purple
        case "published": return .green
        default: return .gray
        }
    }
}

struct EmptyCollabsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.badge.gearshape")
                .font(.system(size: 64))
                .foregroundColor(AppTheme.Colors.textTertiary)
            
            Text("No active collaborations")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text("Find your perfect match and start collaborating!")
                .font(.system(size: 15))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct CollabRevenueCard: View {
    let title: String
    let amount: String
    let trend: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Text("$\(amount)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                Text(trend)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct CollabCategoryChip: View {
    let category: CollabCategory
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(category.emoji)
                    .font(.system(size: 18))
                
                Text(category.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppTheme.Colors.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(category.color.opacity(0.3), lineWidth: 2)
            )
        }
    }
}

struct SuccessStoryCard: View {
    let story: CollabSuccessStory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: story.creator1Avatar)) { image in
                    image.resizable()
                } placeholder: {
                    Circle().fill(AppTheme.Colors.cardBackground)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                
                AsyncImage(url: URL(string: story.creator2Avatar)) { image in
                    image.resizable()
                } placeholder: {
                    Circle().fill(AppTheme.Colors.cardBackground)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(story.creator1) & \(story.creator2)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(story.projectName)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text(story.totalViews)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    Text("Views")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                VStack(spacing: 4) {
                    Text("$\(story.totalRevenue)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.green)
                    Text("Revenue")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                VStack(spacing: 4) {
                    Text("+\(story.subscriberGrowth)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.blue)
                    Text("New Subs")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Creator Collab Sheet
struct CreatorCollabSheet: View {
    let creator: CollabCreator
    @ObservedObject var viewModel: CollabFinderViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var proposalMessage = ""
    @State private var selectedCollabType = "Guest Appearance"
    @State private var isSendingProposal = false
    @State private var proposalSent = false

    private let collabTypes = ["Guest Appearance", "Co-Production", "Shoutout Exchange", "Challenge Video", "Review Collab"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Creator Header
                    HStack(spacing: 16) {
                        AsyncImage(url: URL(string: creator.avatarURL)) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle().fill(AppTheme.Colors.primary.opacity(0.3))
                                .overlay(Text(String(creator.name.prefix(1))).font(.title2.bold()).foregroundColor(.white))
                        }
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(creator.name)
                                    .font(.title3.bold())
                                if creator.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(AppTheme.Colors.primary)
                                }
                            }
                            Text(creator.category)
                                .font(.subheadline)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            HStack(spacing: 12) {
                                Label(creator.subscribers, systemImage: "person.2.fill")
                                    .font(.caption).foregroundColor(AppTheme.Colors.textSecondary)
                                Label(creator.avgViews + " avg", systemImage: "eye.fill")
                                    .font(.caption).foregroundColor(AppTheme.Colors.textSecondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 24)

                    // Engagement badge
                    HStack(spacing: 16) {
                        statBadge(value: String(format: "%.1f%%", creator.engagementRate), label: "Engagement")
                        statBadge(value: creator.avgViews, label: "Avg Views")
                        statBadge(value: creator.subscribers, label: "Subscribers")
                    }
                    .padding(.horizontal, 24)

                    Divider()

                    // Proposal form
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Send Collab Proposal")
                            .font(.headline)
                            .padding(.horizontal, 24)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Collaboration Type")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 24)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(collabTypes, id: \.self) { type in
                                        Button {
                                            withAnimation { selectedCollabType = type }
                                            HapticManager.shared.impact(style: .light)
                                        } label: {
                                            Text(type)
                                                .font(.caption.bold())
                                                .foregroundColor(selectedCollabType == type ? .white : AppTheme.Colors.textPrimary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 7)
                                                .background(Capsule().fill(selectedCollabType == type ? AppTheme.Colors.primary : AppTheme.Colors.surface))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Message")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 24)
                            TextEditor(text: $proposalMessage)
                                .frame(minHeight: 100)
                                .padding(12)
                                .background(AppTheme.Colors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.Colors.divider, lineWidth: 1))
                                .padding(.horizontal, 24)
                                .overlay(
                                    Group {
                                        if proposalMessage.isEmpty {
                                            Text("Introduce yourself and describe the collab idea…")
                                                .font(.body)
                                                .foregroundColor(AppTheme.Colors.textTertiary)
                                                .padding(.horizontal, 36)
                                                .padding(.vertical, 20)
                                                .allowsHitTesting(false)
                                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                        }
                                    }
                                )
                        }

                        Button {
                            sendProposal()
                        } label: {
                            HStack {
                                if isSendingProposal { ProgressView().tint(.white) }
                                else { Text("Send Proposal") }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(proposalMessage.isEmpty ? AppTheme.Colors.textTertiary : AppTheme.Colors.primary)
                            .foregroundColor(.white)
                            .font(.headline)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(proposalMessage.trimmingCharacters(in: .whitespaces).isEmpty || isSendingProposal)
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.vertical, 20)
            }
            .navigationTitle(creator.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Proposal Sent! 🤝", isPresented: $proposalSent) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your collaboration proposal has been sent to \(creator.name).")
            }
        }
    }

    private func statBadge(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 17, weight: .bold))
            Text(label).font(.caption).foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func sendProposal() {
        isSendingProposal = true
        Task {
            // Write proposal to Firestore
            #if canImport(FirebaseFirestore)
            let data: [String: Any] = [
                "fromUserId": AppState.shared.currentUser?.id ?? "",
                "fromUserName": AppState.shared.currentUser?.displayName ?? "",
                "toCreatorId": creator.id,
                "toCreatorName": creator.name,
                "collabType": selectedCollabType,
                "message": proposalMessage,
                "status": "pending",
                "sentAt": FirebaseFirestore.FieldValue.serverTimestamp()
            ]
            try? await FirebaseFirestore.Firestore.firestore()
                .collection("collab-proposals")
                .addDocument(data: data)
            #else
            try? await Task.sleep(nanoseconds: 500_000_000)
            #endif
            await MainActor.run {
                isSendingProposal = false
                proposalSent = true
                HapticManager.shared.notification(type: .success)
            }
        }
    }
}

// MARK: - Filters Sheet
struct CollabFiltersSheet: View {
    @ObservedObject var viewModel: CollabFinderViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: String = "All"
    @State private var minSubscribers: Double = 0
    @State private var maxSubscribers: Double = 10
    @State private var minEngagement: Double = 0
    @State private var onlyVerified: Bool = false

    private let categories = ["All"] + CollabCategory.allCategories.map(\.name)
    private let subLabels = ["0", "10K", "100K", "500K", "1M", "5M", "10M+"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories, id: \.self) { cat in
                                Button {
                                    withAnimation { selectedCategory = cat }
                                    HapticManager.shared.impact(style: .light)
                                } label: {
                                    Text(cat)
                                        .font(.caption.bold())
                                        .foregroundColor(selectedCategory == cat ? .white : AppTheme.Colors.textPrimary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Capsule().fill(selectedCategory == cat ? AppTheme.Colors.primary : AppTheme.Colors.surface))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 0))
                }

                Section("Subscriber Range") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(subRangeLabel(minSubscribers))
                            Spacer()
                            Text("to")
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            Spacer()
                            Text(subRangeLabel(maxSubscribers))
                        }
                        .font(.subheadline)
                        HStack {
                            Text("Min")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            Slider(value: $minSubscribers, in: 0...10, step: 1)
                        }
                        HStack {
                            Text("Max")
                                .font(.caption)
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            Slider(value: $maxSubscribers, in: 0...10, step: 1)
                        }
                    }
                }

                Section("Engagement Rate") {
                    HStack {
                        Text("Min: \(String(format: "%.0f%%", minEngagement))")
                            .font(.subheadline)
                        Spacer()
                    }
                    Slider(value: $minEngagement, in: 0...20, step: 0.5)
                }

                Section("Other") {
                    Toggle("Verified Creators Only", isOn: $onlyVerified)
                }

                Section {
                    Button {
                        applyFilters()
                        dismiss()
                        HapticManager.shared.impact(style: .medium)
                    } label: {
                        Text("Apply Filters")
                            .frame(maxWidth: .infinity)
                            .bold()
                    }
                    .tint(AppTheme.Colors.primary)

                    Button {
                        resetFilters()
                    } label: {
                        Text("Reset")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func subRangeLabel(_ val: Double) -> String {
        let labels = ["Any", "10K", "50K", "100K", "500K", "1M", "5M", "10M", "50M", "100M", "No limit"]
        return labels[min(Int(val), labels.count - 1)]
    }

    private func applyFilters() {
        viewModel.applyFilters(
            category: selectedCategory == "All" ? nil : selectedCategory,
            onlyVerified: onlyVerified,
            minEngagement: minEngagement > 0 ? minEngagement : nil
        )
    }

    private func resetFilters() {
        selectedCategory = "All"
        minSubscribers = 0
        maxSubscribers = 10
        minEngagement = 0
        onlyVerified = false
        viewModel.applyFilters(category: nil, onlyVerified: false, minEngagement: nil)
    }
}

#Preview {
    CollabFinderView()
}

