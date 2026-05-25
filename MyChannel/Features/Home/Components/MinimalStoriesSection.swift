//
//  MinimalStoriesSection.swift
//  MyChannel
//
//  Extracted from HomeView.swift for better code organization
//

import SwiftUI

// MARK: - Minimal Stories Section
struct MinimalStoriesSection: View {
    let stories: [AssetStory]
    let onStoryTap: (AssetStory) -> Void
    let onAddStory: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                // Add Story Button
                addStoryButton
                
                // Story Items
                ForEach(stories) { story in
                    storyItem(story)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Add Story Button
    @ViewBuilder
    private var addStoryButton: some View {
        Button(action: onAddStory) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 60, height: 60)

                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }

                Text("Your Story")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Story Item
    @ViewBuilder
    private func storyItem(_ story: AssetStory) -> some View {
        Button(action: { onStoryTap(story) }) {
            VStack(spacing: 8) {
                ZStack {
                    // Gradient Ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.pink, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 64, height: 64)

                    // Profile Image
                    storyProfileImage(story)
                }

                Text(story.username)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Story Profile Image
    @ViewBuilder
    private func storyProfileImage(_ story: AssetStory) -> some View {
        if UIImage(named: story.authorImageName) != nil {
            Image(story.authorImageName)
                .resizable()
                .scaledToFill()
                .frame(width: 58, height: 58)
                .clipShape(Circle())
        } else {
            AppAsyncImage(url: URL(string: "https://picsum.photos/200/200?random=\(abs(story.id.hashValue))")) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 58, height: 58)
                    .clipShape(Circle())
            } placeholder: {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 58, height: 58)
            }
        }
    }
}

#Preview {
    MinimalStoriesSection(
        stories: [],
        onStoryTap: { _ in },
        onAddStory: {}
    )
}






