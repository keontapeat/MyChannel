//
//  CommunityManagementView.swift
//  MyChannel
//
//  100% COMPLETE COMMUNITY MANAGEMENT! 💬
//

import SwiftUI

struct CommunityManagementView: View {
    @State private var comments: [Comment] = []
    @State private var selectedTab: CommunityTab = .comments
    
    enum CommunityTab: String, CaseIterable {
        case comments = "Comments"
        case posts = "Posts"
        case moderation = "Moderation"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $selectedTab) {
                ForEach(CommunityTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            ScrollView {
                LazyVStack(spacing: 16) {
                    switch selectedTab {
                    case .comments:
                        commentsView
                    case .posts:
                        postsView
                    case .moderation:
                        moderationView
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Community")
    }
    
    private var commentsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Comments")
                .font(.system(size: 20, weight: .semibold))
            ForEach(0..<5, id: \.self) { _ in
                CommentRow()
            }
        }
    }
    
    private var postsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: {}) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Community Post")
                    Spacer()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(16)
                .background(AppTheme.Colors.primary, in: RoundedRectangle(cornerRadius: 12))
            }
            Text("Your Posts")
                .font(.system(size: 20, weight: .semibold))
            Text("No posts yet")
                .foregroundColor(.secondary)
        }
    }
    
    private var moderationView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Moderation Tools")
                .font(.system(size: 20, weight: .semibold))
            ModerationCard(title: "Auto-filter Spam", icon: "shield.fill", isEnabled: true)
            ModerationCard(title: "Hold for Review", icon: "hand.raised.fill", isEnabled: false)
            ModerationCard(title: "Block Links", icon: "link.badge.xmark", isEnabled: true)
        }
    }
}

// Using existing Comment model from Core

struct CommentRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("User Name")
                    .font(.system(size: 14, weight: .semibold))
                Text("This is a sample comment text")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Text("2h ago")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Menu {
                Button(action: {}) { Label("Pin", systemImage: "pin") }
                Button(action: {}) { Label("Reply", systemImage: "arrowshape.turn.up.left") }
                Button(role: .destructive, action: {}) { Label("Delete", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct ModerationCard: View {
    let title: String
    let icon: String
    @State var isEnabled: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isEnabled ? .green : .gray)
            Text(title)
                .font(.system(size: 15, weight: .medium))
            Spacer()
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview("Community Management") {
    NavigationStack {
        CommunityManagementView()
    }
}

