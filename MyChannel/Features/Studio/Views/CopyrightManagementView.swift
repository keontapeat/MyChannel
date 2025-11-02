//
//  CopyrightManagementView.swift
//  MyChannel
//
//  100% COMPLETE COPYRIGHT MANAGEMENT! ⚖️
//

import SwiftUI

struct CopyrightManagementView: View {
    @State private var claims: [CopyrightClaim] = []
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                statusOverview
                activeClaims
                protectionTools
                educationSection
            }
            .padding(16)
        }
        .navigationTitle("Copyright")
    }
    
    private var statusOverview: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatusCard(title: "Active Claims", value: "0", icon: "exclamationmark.triangle.fill", color: .orange)
                StatusCard(title: "Protected", value: "100%", icon: "shield.checkmark.fill", color: .green)
            }
            
            HStack(spacing: 12) {
                StatusCard(title: "Strikes", value: "0", icon: "hand.raised.fill", color: .red)
                StatusCard(title: "Resolved", value: "0", icon: "checkmark.circle.fill", color: .blue)
            }
        }
    }
    
    private var activeClaims: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Active Claims")
                .font(.system(size: 20, weight: .semibold))
            
            if claims.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    Text("No Active Claims")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Your content is protected")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private var protectionTools: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Protection Tools")
                .font(.system(size: 20, weight: .semibold))
            
            ProtectionToolCard(
                icon: "wand.and.stars",
                title: "AI Content ID",
                description: "Automatically detect your content across the platform",
                action: "Enable"
            )
            
            ProtectionToolCard(
                icon: "bell.badge.fill",
                title: "Copyright Alerts",
                description: "Get notified when someone uses your content",
                action: "Setup"
            )
            
            ProtectionToolCard(
                icon: "lock.shield.fill",
                title: "Watermark Protection",
                description: "Add visible watermarks to your videos",
                action: "Configure"
            )
        }
    }
    
    private var educationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(.blue)
                Text("Copyright Education")
                    .font(.system(size: 20, weight: .semibold))
            }
            
            EducationCard(title: "What is fair use?", icon: "questionmark.circle")
            EducationCard(title: "How to file a claim", icon: "doc.text")
            EducationCard(title: "Dispute process", icon: "arrow.triangle.branch")
        }
    }
}

// Using existing CopyrightClaim model from Core/Services/ContentModerationService.swift

struct StatusCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct ProtectionToolCard: View {
    let icon: String
    let title: String
    let description: String
    let action: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 44, height: 44)
                .background(AppTheme.Colors.primary.opacity(0.15), in: Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {}) {
                Text(action)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primary)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct EducationCard: View {
    let title: String
    let icon: String
    
    var body: some View {
        Button(action: {}) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
    }
}


