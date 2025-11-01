//
//  ChannelCustomizationView.swift
//  MyChannel
//
//  100% COMPLETE CHANNEL CUSTOMIZATION! 🎨
//

import SwiftUI
import PhotosUI

struct ChannelCustomizationView: View {
    @State private var bannerImage: UIImage?
    @State private var profileImage: UIImage?
    @State private var channelName = "My Channel"
    @State private var description = ""
    @State private var showingBannerPicker = false
    @State private var showingProfilePicker = false
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                bannerSection
                profileSection
                detailsSection
                socialLinksSection
                themingSection
                saveButton
            }
            .padding(16)
        }
        .navigationTitle("Customization")
    }
    
    private var bannerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Channel Banner")
                .font(.system(size: 18, weight: .semibold))
            Button(action: { showingBannerPicker = true }) {
                if let banner = bannerImage {
                    Image(uiImage: banner)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(height: 120)
                        .overlay(Text("Upload Banner").foregroundColor(.secondary))
                }
            }
        }
    }
    
    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile Picture")
                .font(.system(size: 18, weight: .semibold))
            Button(action: { showingProfilePicker = true }) {
                if let profile = profileImage {
                    Image(uiImage: profile)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 100, height: 100)
                        .overlay(Image(systemName: "person.circle").font(.system(size: 40)).foregroundColor(.secondary))
                }
            }
        }
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Channel Details")
                .font(.system(size: 18, weight: .semibold))
            TextField("Channel Name", text: $channelName)
                .textFieldStyle(.roundedBorder)
            TextField("Description", text: $description, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(5...10)
        }
    }
    
    private var socialLinksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Social Links")
                .font(.system(size: 18, weight: .semibold))
            TextField("Instagram", text: .constant(""))
                .textFieldStyle(.roundedBorder)
            TextField("Twitter", text: .constant(""))
                .textFieldStyle(.roundedBorder)
            TextField("Website", text: .constant(""))
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var themingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Theme")
                .font(.system(size: 18, weight: .semibold))
            HStack(spacing: 12) {
                ForEach([Color.blue, .purple, .green, .orange, .pink], id: \.self) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
        }
    }
    
    private var saveButton: some View {
        Button(action: {}) {
            Text("Save Changes")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.Colors.primary, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview("Studio View") {
    NavigationStack {
        ChannelCustomizationView()
    }
}

